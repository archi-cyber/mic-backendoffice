import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { AppConfig } from '../../config/configuration';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  RecordPaymentDto,
  UpdatePenaltySettingsDto,
} from './dto/task.dto';

export interface PenaltyBalance {
  memberId: string;
  totalPenalties: number;
  totalPaid: number;
  balance: number;
  isBlocked: boolean;
  threshold: number;
}

@Injectable()
export class PenaltiesService {
  private readonly logger = new Logger(PenaltiesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  // ===========================================================================
  // Paramètres
  // ===========================================================================

  /**
   * Paramètres globaux, avec repli sur la configuration d'environnement.
   *
   * La table peut être vide si le seed n'a pas tourné. Plutôt que d'échouer,
   * on retombe sur les valeurs par défaut — un calcul de pénalité ne doit pas
   * bloquer parce qu'une ligne de configuration manque.
   */
  async getSettings() {
    const stored = await this.prisma.taskPenaltySettings.findUnique({
      where: { id: 'global' },
    });

    if (stored) {
      return stored;
    }

    const business = this.config.get('business', { infer: true });

    return {
      id: 'global',
      defaultDailyPenaltyAmount: business.defaultDailyPenaltyAmount,
      blockingThresholdAmount: business.blockingThresholdAmount,
      teachingTaskDueOffsetDays: business.teachingTaskDueOffsetDays,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
  }

  async updateSettings(dto: UpdatePenaltySettingsDto) {
    const current = await this.getSettings();

    return this.prisma.taskPenaltySettings.upsert({
      where: { id: 'global' },
      update: dto,
      create: {
        id: 'global',
        defaultDailyPenaltyAmount:
          dto.defaultDailyPenaltyAmount ?? current.defaultDailyPenaltyAmount,
        blockingThresholdAmount:
          dto.blockingThresholdAmount ?? current.blockingThresholdAmount,
        teachingTaskDueOffsetDays:
          dto.teachingTaskDueOffsetDays ?? current.teachingTaskDueOffsetDays,
      },
    });
  }

  // ===========================================================================
  // Soldes
  // ===========================================================================

  /**
   * Solde de pénalités d'un membre.
   *
   * Le solde est la différence entre les pénalités accumulées et les
   * versements enregistrés. Un membre au-delà du seuil ne peut plus recevoir
   * de nouvelle tâche.
   */
  async getBalance(memberId: string): Promise<PenaltyBalance> {
    const settings = await this.getSettings();

    const [penalties, payments] = await this.prisma.$transaction([
      this.prisma.taskPenalty.aggregate({
        where: { memberId },
        _sum: { amount: true },
      }),
      this.prisma.taskPenaltyPayment.aggregate({
        where: { memberId },
        _sum: { amount: true },
      }),
    ]);

    const totalPenalties = penalties._sum.amount ?? 0;
    const totalPaid = payments._sum.amount ?? 0;
    const balance = totalPenalties - totalPaid;

    return {
      memberId,
      totalPenalties,
      totalPaid,
      balance,
      isBlocked: balance >= settings.blockingThresholdAmount,
      threshold: settings.blockingThresholdAmount,
    };
  }

  /**
   * Soldes de plusieurs membres, en une seule passe.
   *
   * Appelée avant chaque assignation groupée : interroger la base membre par
   * membre multiplierait les requêtes pour une vérification qui doit rester
   * imperceptible.
   */
 /**
   * Soldes de plusieurs membres, en une seule passe.
   *
   * Appelée avant chaque assignation groupée : interroger la base membre par
   * membre multiplierait les requêtes pour une vérification qui doit rester
   * imperceptible.
   */
  async getBalances(memberIds: string[]): Promise<Map<string, PenaltyBalance>> {
    const settings = await this.getSettings();
    const unique = [...new Set(memberIds)];

    const [penalties, payments] = await this.prisma.$transaction([
      this.prisma.taskPenalty.groupBy({
        by: ['memberId'],
        where: { memberId: { in: unique } },
        _sum: { amount: true },
        // `orderBy` est obligatoire sur un groupBy Prisma. Sans lui, le type
        // de `_sum` reste indéterminé et TypeScript refuse d'y accéder.
        orderBy: { memberId: 'asc' },
      }),
      this.prisma.taskPenaltyPayment.groupBy({
        by: ['memberId'],
        where: { memberId: { in: unique } },
        _sum: { amount: true },
        orderBy: { memberId: 'asc' },
      }),
    ]);

    const penaltyByMember = new Map(
      penalties.map((row) => [row.memberId, row._sum?.amount ?? 0]),
    );
    const paymentByMember = new Map(
      payments.map((row) => [row.memberId, row._sum?.amount ?? 0]),
    );

    return new Map(
      unique.map((memberId) => {
        const totalPenalties = penaltyByMember.get(memberId) ?? 0;
        const totalPaid = paymentByMember.get(memberId) ?? 0;
        const balance = totalPenalties - totalPaid;

        return [
          memberId,
          {
            memberId,
            totalPenalties,
            totalPaid,
            balance,
            isBlocked: balance >= settings.blockingThresholdAmount,
            threshold: settings.blockingThresholdAmount,
          },
        ];
      }),
    );
  }
  /** Membres ayant un solde impayé, du plus élevé au plus faible. */
  async findUnpaidBalances() {
    const settings = await this.getSettings();

    const rows = await this.prisma.$queryRaw<
      Array<{
        memberId: string;
        firstName: string;
        lastName: string;
        photoUrl: string | null;
        totalPenalties: bigint;
        totalPaid: bigint;
      }>
    >`
      SELECT
        m.id            AS "memberId",
        m.first_name    AS "firstName",
        m.last_name     AS "lastName",
        m.photo_url     AS "photoUrl",
        COALESCE(p.total, 0)  AS "totalPenalties",
        COALESCE(pay.total, 0) AS "totalPaid"
      FROM members m
      LEFT JOIN (
        SELECT member_id, SUM(amount) AS total
        FROM task_penalties GROUP BY member_id
      ) p ON p.member_id = m.id
      LEFT JOIN (
        SELECT member_id, SUM(amount) AS total
        FROM task_penalty_payments GROUP BY member_id
      ) pay ON pay.member_id = m.id
      WHERE m.deleted_at IS NULL
        AND COALESCE(p.total, 0) - COALESCE(pay.total, 0) > 0
      ORDER BY (COALESCE(p.total, 0) - COALESCE(pay.total, 0)) DESC
    `;

    return rows.map((row) => {
      const totalPenalties = Number(row.totalPenalties);
      const totalPaid = Number(row.totalPaid);
      const balance = totalPenalties - totalPaid;

      return {
        memberId: row.memberId,
        firstName: row.firstName,
        lastName: row.lastName,
        photoUrl: row.photoUrl,
        totalPenalties,
        totalPaid,
        balance,
        isBlocked: balance >= settings.blockingThresholdAmount,
      };
    });
  }

  /** Détail des pénalités d'un membre, tâche par tâche. */
  async findMemberPenalties(memberId: string) {
    const [penalties, payments, balance] = await Promise.all([
      this.prisma.taskPenalty.findMany({
        where: { memberId },
        orderBy: { penaltyDate: 'desc' },
        include: {
          task: { select: { id: true, title: true, dueDate: true, status: true } },
        },
      }),
      this.prisma.taskPenaltyPayment.findMany({
        where: { memberId },
        orderBy: { paidAt: 'desc' },
      }),
      this.getBalance(memberId),
    ]);

    return { balance, penalties, payments };
  }

  // ===========================================================================
  // Versements
  // ===========================================================================

  async recordPayment(
    memberId: string,
    dto: RecordPaymentDto,
    actorUserId: string,
  ) {
    const member = await this.prisma.member.findFirst({
      where: { id: memberId, ...NOT_DELETED },
      select: { id: true, firstName: true, lastName: true },
    });

    if (!member) {
      throw new NotFoundException({
        message: 'Membre introuvable.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    const payment = await this.prisma.taskPenaltyPayment.create({
      data: {
        memberId,
        amount: dto.amount,
        note: dto.note ?? null,
        recordedBy: actorUserId,
      },
    });

    const balance = await this.getBalance(memberId);

    this.logger.log(
      `Versement de ${dto.amount} frs pour ${member.firstName} ${member.lastName} ` +
        `(solde restant : ${balance.balance} frs)`,
    );

    return { payment, balance };
  }

  // ===========================================================================
  // Calcul
  // ===========================================================================

  /**
   * Génère les pénalités du jour pour toutes les tâches en retard.
   *
   * Une ligne est créée par tâche, par membre assigné et par jour de retard.
   * Le premier jour pénalisé est **le lendemain** de l'échéance : rendre un
   * travail le jour même reste dans les temps.
   *
   * L'opération est idempotente grâce à la contrainte d'unicité
   * (task, member, date) — relancer le calcul sur une date déjà traitée ne
   * produit aucun doublon. C'est indispensable pour rattraper une journée
   * manquée après une interruption de service.
   */
  async runDailyPenalties(referenceDate = new Date()) {
    const today = this.startOfDay(referenceDate);
    const settings = await this.getSettings();

    const overdueTasks = await this.prisma.task.findMany({
      where: {
        ...NOT_DELETED,
        // Une tâche archivée sort du calcul : c'est le geste par lequel un
        // responsable acte qu'elle n'a plus lieu d'être suivie.
        archivedAt: null,
        status: { in: ['pending', 'in_progress'] },
        dueDate: { lt: today },
        assignments: { some: {} },
      },
      select: {
        id: true,
        title: true,
        dueDate: true,
        penaltyAmountPerDay: true,
        department: { select: { taskPenaltyAmount: true } },
        assignments: { select: { memberId: true } },
      },
    });

    let created = 0;

    for (const task of overdueTasks) {
      const amount = this.resolveAmount(task, settings.defaultDailyPenaltyAmount);

      // Un montant nul signifie que le département a explicitement renoncé
      // aux pénalités : inutile de créer des lignes à zéro.
      if (amount <= 0) continue;

      for (const assignment of task.assignments) {
        const existing = await this.prisma.taskPenalty.findUnique({
          where: {
            taskId_memberId_penaltyDate: {
              taskId: task.id,
              memberId: assignment.memberId,
              penaltyDate: today,
            },
          },
          select: { id: true },
        });

        if (existing) continue;

        await this.prisma.taskPenalty.create({
          data: {
            taskId: task.id,
            memberId: assignment.memberId,
            penaltyDate: today,
            amount,
          },
        });

        created += 1;
      }
    }

    this.logger.log(
      `Pénalités du ${today.toISOString().slice(0, 10)} : ` +
        `${created} ligne(s) créée(s) sur ${overdueTasks.length} tâche(s) en retard.`,
    );

    return {
      date: today,
      overdueTasks: overdueTasks.length,
      penaltiesCreated: created,
    };
  }

  /**
   * Détermine le montant journalier applicable.
   *
   * Trois niveaux, du plus spécifique au plus général : la tâche, puis son
   * département, puis le paramètre global. Cette cascade permet à un
   * département d'appliquer son propre barème sans toucher aux autres, et à
   * une tâche particulière de déroger ponctuellement.
   *
   * La comparaison porte sur `null` et non sur une valeur falsy : un montant
   * de zéro est un choix délibéré — « pas de pénalité sur cette tâche » — et
   * ne doit pas basculer sur le niveau supérieur.
   */
  private resolveAmount(
    task: {
      penaltyAmountPerDay: number | null;
      department: { taskPenaltyAmount: number | null } | null;
    },
    globalAmount: number,
  ): number {
    if (task.penaltyAmountPerDay !== null) {
      return task.penaltyAmountPerDay;
    }
    if (task.department?.taskPenaltyAmount != null) {
      return task.department.taskPenaltyAmount;
    }
    return globalAmount;
  }

  private startOfDay(date: Date): Date {
    const result = new Date(date);
    result.setUTCHours(0, 0, 0, 0);
    return result;
  }
}