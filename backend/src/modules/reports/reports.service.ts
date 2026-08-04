import { Injectable, Logger, NotFoundException } from '@nestjs/common';

import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  AttendanceReportDto,
  NewcomersReportDto,
  ReportPeriodDto,
} from './dto/report.dto';

/** Qualification de l'assiduité d'un membre. */
export type DiligenceLevel = 'diligent' | 'moderate' | 'low';

@Injectable()
export class ReportsService {
  private readonly logger = new Logger(ReportsService.name);

  private static readonly DEFAULT_DILIGENT_THRESHOLD = 75;
  private static readonly DEFAULT_MODERATE_THRESHOLD = 50;

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Tableau de bord
  // ===========================================================================

  /**
   * Vue d'ensemble affichée à l'ouverture de l'application.
   *
   * Toutes les requêtes partent en parallèle : elles sont indépendantes, et
   * les enchaîner ferait attendre l'utilisateur pour rien sur un écran qui
   * doit s'afficher immédiatement.
   */
  async getDashboard() {
    const today = this.startOfDay(new Date());
    const in30Days = this.addDays(today, 30);
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

    const [
      memberCount,
      newcomerCount,
      upcomingEvents,
      upcomingSessions,
      openTasks,
      overdueTasks,
      recentServices,
      monthAttendance,
    ] = await Promise.all([
      this.prisma.member.count({ where: { ...NOT_DELETED, isActive: true } }),
      this.prisma.member.count({
        where: { ...NOT_DELETED, isActive: true, isNewComer: true },
      }),
      this.prisma.event.findMany({
        where: { ...NOT_DELETED, isActive: true, eventDate: { gte: today } },
        orderBy: { eventDate: 'asc' },
        take: 5,
        select: { id: true, title: true, eventDate: true, location: true },
      }),
      this.prisma.session.findMany({
        where: { sessionDate: { gte: today, lte: in30Days } },
        orderBy: { sessionDate: 'asc' },
        take: 5,
        select: {
          id: true,
          sessionDate: true,
          class: { select: { id: true, name: true } },
        },
      }),
      this.prisma.task.count({
        where: {
          ...NOT_DELETED,
          archivedAt: null,
          status: { in: ['pending', 'in_progress'] },
        },
      }),
      this.prisma.task.count({
        where: {
          ...NOT_DELETED,
          archivedAt: null,
          status: { in: ['pending', 'in_progress'] },
          dueDate: { lt: today },
        },
      }),
      this.prisma.churchService.findMany({
        where: { ...NOT_DELETED },
        orderBy: { serviceDate: 'desc' },
        take: 5,
        select: {
          id: true,
          name: true,
          serviceDate: true,
          _count: { select: { attendances: { where: { deletedAt: null } } } },
        },
      }),
      this.prisma.churchAttendance.count({
        where: {
          ...NOT_DELETED,
          serviceDate: { gte: monthStart },
          attendanceType: { in: ['onsite', 'online'] },
        },
      }),
    ]);

    const birthdays = await this.getBirthdaysThisMonth();

    return {
      members: {
        total: memberCount,
        newcomers: newcomerCount,
      },
      tasks: {
        open: openTasks,
        overdue: overdueTasks,
      },
      attendance: {
        presencesThisMonth: monthAttendance,
        recentServices,
      },
      upcomingEvents,
      upcomingSessions,
      birthdaysThisMonth: birthdays,
    };
  }

  // ===========================================================================
  // Présence aux cultes
  // ===========================================================================

  /**
   * Rapport de présence par membre, avec taux d'assiduité.
   *
   * Le dénominateur est le nombre de cultes **tenus** sur la période, non le
   * nombre de fois où la personne a été pointée. Un membre jamais pointé
   * apparaît donc avec un taux de zéro, ce qui est l'information utile pour
   * le suivi pastoral — l'oubli de pointage et l'absence appellent le même
   * geste : aller voir.
   */
  async getAttendanceReport(query: AttendanceReportDto) {
    const diligent =
      query.diligentThreshold ?? ReportsService.DEFAULT_DILIGENT_THRESHOLD;
    const moderate =
      query.moderateThreshold ?? ReportsService.DEFAULT_MODERATE_THRESHOLD;

    const dateFilter = this.buildDateFilter(query.from, query.to);

    const [services, members, attendances] = await Promise.all([
      this.prisma.churchService.findMany({
        where: { ...NOT_DELETED, ...(dateFilter ? { serviceDate: dateFilter } : {}) },
        orderBy: { serviceDate: 'asc' },
        select: { id: true, name: true, serviceDate: true },
      }),
      this.prisma.member.findMany({
        where: {
          ...NOT_DELETED,
          isActive: true,
          ...(query.departmentId
            ? { departmentMembers: { some: { departmentId: query.departmentId } } }
            : {}),
        },
        orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
        select: {
          id: true,
          firstName: true,
          lastName: true,
          role: true,
          isNewComer: true,
          mainDepartment: { select: { id: true, name: true } },
        },
      }),
      this.prisma.churchAttendance.findMany({
        where: { ...NOT_DELETED, ...(dateFilter ? { serviceDate: dateFilter } : {}) },
        select: {
          memberId: true,
          churchServiceId: true,
          attendanceType: true,
          specificObservation: true,
        },
      }),
    ]);

    const totalServices = services.length;

    // Regroupement en mémoire : une requête par membre serait ruineuse sur une
    // assemblée de plusieurs centaines de personnes.
    const byMember = new Map<string, typeof attendances>();
    for (const entry of attendances) {
      const list = byMember.get(entry.memberId) ?? [];
      list.push(entry);
      byMember.set(entry.memberId, list);
    }

    const rows = members.map((member) => {
      const own = byMember.get(member.id) ?? [];
      const onsite = own.filter((e) => e.attendanceType === 'onsite').length;
      const online = own.filter((e) => e.attendanceType === 'online').length;
      const absent = own.filter((e) => e.attendanceType === 'absent').length;
      const present = onsite + online;

      const rate =
        totalServices > 0 ? Math.round((present / totalServices) * 100) : 0;

      return {
        ...member,
        onsite,
        online,
        absent,
        present,
        notRecorded: totalServices - own.length,
        attendanceRate: rate,
        diligence: this.qualifyDiligence(rate, diligent, moderate),
        observations: own
          .map((e) => e.specificObservation)
          .filter((note): note is string => Boolean(note)),
      };
    });

    return {
      period: { from: query.from ?? null, to: query.to ?? null },
      thresholds: { diligent, moderate },
      totalServices,
      totalMembers: members.length,
      summary: {
        diligent: rows.filter((r) => r.diligence === 'diligent').length,
        moderate: rows.filter((r) => r.diligence === 'moderate').length,
        low: rows.filter((r) => r.diligence === 'low').length,
      },
      services,
      members: rows,
    };
  }

  /**
   * Fréquentation culte par culte, dans l'ordre chronologique.
   *
   * Format directement exploitable pour un graphique d'évolution.
   */
  async getAttendanceTrend(query: ReportPeriodDto) {
    // Les bornes sont explicitement converties en null : passer `undefined`
    // a une requete parametree provoque une erreur cote Prisma.
    const from = query.from ?? null;
    const to = query.to ?? null;

    const rows = await this.prisma.$queryRaw<
      Array<{
        serviceId: string;
        name: string;
        serviceDate: Date;
        onsite: bigint;
        online: bigint;
        absent: bigint;
        visitors: bigint;
      }>
    >`
      SELECT
        cs.id           AS "serviceId",
        cs.name         AS "name",
        cs.service_date AS "serviceDate",
        COUNT(*) FILTER (WHERE ca.attendance_type = 'onsite')  AS "onsite",
        COUNT(*) FILTER (WHERE ca.attendance_type = 'online')  AS "online",
        COUNT(*) FILTER (WHERE ca.attendance_type = 'absent')  AS "absent",
        (
          SELECT COUNT(*) FROM visitors v
          WHERE v.church_service_id = cs.id AND v.deleted_at IS NULL
        ) AS "visitors"
      FROM church_services cs
      LEFT JOIN church_attendance ca
        ON ca.church_service_id = cs.id AND ca.deleted_at IS NULL
      WHERE cs.deleted_at IS NULL
        AND (${from}::date IS NULL OR cs.service_date >= ${from}::date)
        AND (${to}::date   IS NULL OR cs.service_date <= ${to}::date)
      GROUP BY cs.id, cs.name, cs.service_date
      ORDER BY cs.service_date ASC
    `;

    return rows.map((row) => {
      const onsite = Number(row.onsite);
      const online = Number(row.online);

      return {
        serviceId: row.serviceId,
        name: row.name,
        serviceDate: row.serviceDate,
        onsite,
        online,
        absent: Number(row.absent),
        visitors: Number(row.visitors),
        totalPresent: onsite + online,
      };
    });
  }

  // ===========================================================================
  // Nouveaux venus
  // ===========================================================================

  /**
   * Suivi des nouveaux venus.
   *
   * Croise leur date d'arrivée avec leur présence effective, pour repérer
   * ceux qui décrochent — l'intérêt principal d'un tel rapport n'est pas de
   * compter les arrivées, mais d'identifier qui n'est pas revenu.
   */
  async getNewcomersReport(query: NewcomersReportDto) {
    const windowDays = query.windowDays ?? 90;
    const since = this.addDays(new Date(), -windowDays);
    const dateFilter = this.buildDateFilter(query.from, query.to);

    const newcomers = await this.prisma.member.findMany({
      where: {
        ...NOT_DELETED,
        isNewComer: true,
        ...(dateFilter ? { newcomerJoinDate: dateFilter } : {}),
      },
      orderBy: { newcomerJoinDate: 'desc' },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        phone: true,
        email: true,
        newcomerJoinDate: true,
        newcomerIntention: true,
        churchAttendances: {
          where: {
            deletedAt: null,
            serviceDate: { gte: since },
            attendanceType: { in: ['onsite', 'online'] },
          },
          select: { serviceDate: true },
          orderBy: { serviceDate: 'desc' },
        },
      },
    });

    const rows = newcomers.map((member) => {
      const attendances = member.churchAttendances;
      const lastAttendance = attendances[0]?.serviceDate ?? null;

      return {
        id: member.id,
        firstName: member.firstName,
        lastName: member.lastName,
        phone: member.phone,
        email: member.email,
        joinDate: member.newcomerJoinDate,
        intention: member.newcomerIntention,
        attendanceCount: attendances.length,
        lastAttendance,
        daysSinceLastAttendance: lastAttendance
          ? Math.floor(
              (Date.now() - lastAttendance.getTime()) / (24 * 60 * 60 * 1_000),
            )
          : null,
        // Un nouveau venu sans présence depuis un mois est le signal
        // qu'attend l'équipe d'intégration.
        atRisk:
          !lastAttendance ||
          Date.now() - lastAttendance.getTime() > 30 * 24 * 60 * 60 * 1_000,
      };
    });

    const byIntention = {
      wants_to_stay: rows.filter((r) => r.intention === 'wants_to_stay').length,
      does_not_know_yet: rows.filter((r) => r.intention === 'does_not_know_yet')
        .length,
      just_passing: rows.filter((r) => r.intention === 'just_passing').length,
      unspecified: rows.filter((r) => !r.intention).length,
    };

    return {
      period: { from: query.from ?? null, to: query.to ?? null },
      windowDays,
      total: rows.length,
      atRisk: rows.filter((r) => r.atRisk).length,
      byIntention,
      newcomers: rows,
    };
  }

  // ===========================================================================
  // Rapports individuels
  // ===========================================================================

  /**
   * Bilan complet d'un membre : présence, dons, tâches, formations.
   *
   * Les dons sont volontairement réduits à un total, sans détail par
   * mouvement : ce rapport est consulté par les responsables de département,
   * qui n'ont pas à connaître le détail des offrandes.
   */
  async getMemberReport(memberId: string, query: ReportPeriodDto) {
    const member = await this.prisma.member.findFirst({
      where: { id: memberId, ...NOT_DELETED },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
        phone: true,
        birthday: true,
        role: true,
        isNewComer: true,
        photoUrl: true,
        mainDepartment: { select: { id: true, name: true } },
        departmentMembers: {
          select: {
            role: true,
            department: { select: { id: true, name: true } },
          },
        },
      },
    });

    if (!member) {
      throw new NotFoundException({
        message: 'Membre introuvable.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    const dateFilter = this.buildDateFilter(query.from, query.to);

    const [attendances, totalServices, giving, tasks, penalties, payments, classes] =
      await Promise.all([
        this.prisma.churchAttendance.findMany({
          where: {
            memberId,
            ...NOT_DELETED,
            ...(dateFilter ? { serviceDate: dateFilter } : {}),
          },
          select: { attendanceType: true, serviceDate: true },
        }),
        this.prisma.churchService.count({
          where: { ...NOT_DELETED, ...(dateFilter ? { serviceDate: dateFilter } : {}) },
        }),
        this.prisma.giving.aggregate({
          where: {
            memberId,
            type: 'receiving',
            ...NOT_DELETED,
            ...(dateFilter ? { date: dateFilter } : {}),
          },
          _sum: { amount: true },
          _count: true,
        }),
        this.prisma.taskAssignment.findMany({
          where: { memberId, task: { ...NOT_DELETED } },
          select: {
            status: true,
            task: { select: { id: true, title: true, status: true, dueDate: true } },
          },
        }),
        this.prisma.taskPenalty.aggregate({
          where: { memberId },
          _sum: { amount: true },
        }),
        this.prisma.taskPenaltyPayment.aggregate({
          where: { memberId },
          _sum: { amount: true },
        }),
        this.prisma.classMember.findMany({
          where: { memberId },
          select: { class: { select: { id: true, name: true } } },
        }),
      ]);

    const onsite = attendances.filter((a) => a.attendanceType === 'onsite').length;
    const online = attendances.filter((a) => a.attendanceType === 'online').length;
    const present = onsite + online;

    const completedTasks = tasks.filter(
      (t) => t.task.status === 'completed',
    ).length;

    return {
      member,
      period: { from: query.from ?? null, to: query.to ?? null },
      attendance: {
        totalServices,
        onsite,
        online,
        absent: attendances.filter((a) => a.attendanceType === 'absent').length,
        present,
        rate: totalServices > 0 ? Math.round((present / totalServices) * 100) : 0,
      },
      giving: {
        total: Number(giving._sum.amount ?? 0),
        count: giving._count,
      },
      tasks: {
        total: tasks.length,
        completed: completedTasks,
        pending: tasks.filter((t) => t.task.status === 'pending').length,
        completionRate:
          tasks.length > 0 ? Math.round((completedTasks / tasks.length) * 100) : 0,
      },
      penalties: {
        total: penalties._sum.amount ?? 0,
        paid: payments._sum.amount ?? 0,
        balance: (penalties._sum.amount ?? 0) - (payments._sum.amount ?? 0),
      },
      trainings: classes.map((row) => row.class),
    };
  }

  /** Bilan d'activité d'un département. */
  async getDepartmentReport(departmentId: string, query: ReportPeriodDto) {
    const department = await this.prisma.department.findFirst({
      where: { id: departmentId, ...NOT_DELETED },
      select: { id: true, name: true, description: true },
    });

    if (!department) {
      throw new NotFoundException({
        message: 'Département introuvable.',
        code: 'DEPARTMENT_NOT_FOUND',
      });
    }

    const dateFilter = this.buildDateFilter(query.from, query.to);

    const [members, tasks, projects, reports] = await Promise.all([
      this.prisma.departmentMember.findMany({
        where: { departmentId },
        select: {
          role: true,
          member: {
            select: { id: true, firstName: true, lastName: true, isActive: true },
          },
        },
      }),
      this.prisma.task.findMany({
        where: {
          departmentId,
          ...NOT_DELETED,
          ...(dateFilter ? { createdAt: dateFilter } : {}),
        },
        select: { id: true, status: true, dueDate: true, archivedAt: true },
      }),
      this.prisma.project.count({ where: { departmentId, ...NOT_DELETED } }),
      this.prisma.departmentReport.count({
        where: { departmentId, ...NOT_DELETED },
      }),
    ]);

    const today = this.startOfDay(new Date());
    const completed = tasks.filter((t) => t.status === 'completed').length;

    return {
      department,
      period: { from: query.from ?? null, to: query.to ?? null },
      members: {
        total: members.length,
        active: members.filter((m) => m.member.isActive).length,
        leaders: members.filter((m) => m.role === 'leader').length,
        subleaders: members.filter((m) => m.role === 'subleader').length,
      },
      tasks: {
        total: tasks.length,
        completed,
        pending: tasks.filter((t) => t.status === 'pending').length,
        inProgress: tasks.filter((t) => t.status === 'in_progress').length,
        overdue: tasks.filter(
          (t) =>
            t.dueDate !== null &&
            t.dueDate < today &&
            t.archivedAt === null &&
            (t.status === 'pending' || t.status === 'in_progress'),
        ).length,
        completionRate:
          tasks.length > 0 ? Math.round((completed / tasks.length) * 100) : 0,
      },
      projectCount: projects,
      writtenReportCount: reports,
      roster: members.map((m) => ({ ...m.member, departmentRole: m.role })),
    };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private async getBirthdaysThisMonth() {
    return this.prisma.$queryRaw<
      Array<{ id: string; firstName: string; lastName: string; birthday: Date }>
    >`
      SELECT id, first_name AS "firstName", last_name AS "lastName", birthday
      FROM members
      WHERE deleted_at IS NULL
        AND is_active = true
        AND birthday IS NOT NULL
        AND EXTRACT(MONTH FROM birthday) = EXTRACT(MONTH FROM CURRENT_DATE)
      ORDER BY EXTRACT(DAY FROM birthday) ASC
    `;
  }

  private qualifyDiligence(
    rate: number,
    diligentThreshold: number,
    moderateThreshold: number,
  ): DiligenceLevel {
    if (rate >= diligentThreshold) return 'diligent';
    if (rate >= moderateThreshold) return 'moderate';
    return 'low';
  }

  private buildDateFilter(from?: string, to?: string) {
    if (!from && !to) return null;

    return {
      ...(from ? { gte: new Date(from) } : {}),
      ...(to ? { lte: new Date(to) } : {}),
    };
  }

  private startOfDay(date: Date): Date {
    const result = new Date(date);
    result.setUTCHours(0, 0, 0, 0);
    return result;
  }

  private addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }
}