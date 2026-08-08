import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import type { AppConfig } from '../../config/configuration';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  AddToDepartmentDto,
  CreateMemberDto,
  FindMembersDto,
  UpdateMemberDto,
} from './dto/member.dto';

/** Champs renvoyés dans les listes — allégés par rapport à la fiche complète. */
const LIST_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  email: true,
  phone: true,
  birthday: true,
  photoUrl: true,
  role: true,
  gender: true,
  isActive: true,
  isNewComer: true,
  newcomerIntention: true,
  departmentId: true,
  mainDepartment: { select: { id: true, name: true } },
  createdAt: true,
} satisfies Prisma.MemberSelect;

@Injectable()
export class MembersService {
  private readonly logger = new Logger(MembersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  // ===========================================================================
  // Lecture
  // ===========================================================================

  async findAll(query: FindMembersDto) {
    const where = this.buildWhere(query);

    const orderBy = query.orderBy
      ? { [query.orderBy]: query.order }
      : [{ lastName: 'asc' as const }, { firstName: 'asc' as const }];

    const [items, total] = await this.prisma.$transaction([
      this.prisma.member.findMany({
        where,
        select: LIST_SELECT,
        orderBy,
        skip: query.skip,
        take: query.take,
      }),
      this.prisma.member.count({ where }),
    ]);

    return {
      data: items.map((member) => this.withComputedFields(member)),
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const member = await this.prisma.member.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        mainDepartment: { select: { id: true, name: true } },
        departmentMembers: {
          select: {
            id: true,
            role: true,
            isMain: true,
            department: { select: { id: true, name: true, isActive: true } },
          },
        },
        user: {
          select: {
            id: true,
            email: true,
            role: true,
            isActive: true,
            lastLoginAt: true,
            mustChangePassword: true,
          },
        },
        _count: {
          select: {
            churchAttendances: { where: { deletedAt: null } },
            taskAssignments: true,
            giving: true,
          },
        },
      },
    });

    if (!member) {
      throw this.notFound(id);
    }

    return this.withComputedFields(member);
  }

  /**
   * Anniversaires à venir dans les prochains jours.
   *
   * Le calcul se fait en SQL : comparer des jours et des mois sans tenir
   * compte de l'année n'est pas exprimable proprement avec l'API Prisma, et
   * charger tous les membres en mémoire pour filtrer côté application serait
   * ruineux dès quelques milliers de fiches.
   *
   * L'expression de table (`WITH`) est nécessaire car un alias calculé n'est
   * pas référençable dans la clause `WHERE` de la même requête.
   */
  async findUpcomingBirthdays(daysAhead = 30) {
    return this.prisma.$queryRaw<
      Array<{
        id: string;
        firstName: string;
        lastName: string;
        birthday: Date;
        photoUrl: string | null;
        daysUntil: number;
      }>
    >`
      WITH upcoming AS (
        SELECT
          id,
          first_name AS "firstName",
          last_name  AS "lastName",
          birthday,
          photo_url  AS "photoUrl",
          (
            (
              MAKE_DATE(
                DATE_PART('year', CURRENT_DATE)::int,
                DATE_PART('month', birthday)::int,
                DATE_PART('day', birthday)::int
              )
              -- Si la date est déjà passée cette année, on vise l'an prochain.
              + CASE
                  WHEN MAKE_DATE(
                         DATE_PART('year', CURRENT_DATE)::int,
                         DATE_PART('month', birthday)::int,
                         DATE_PART('day', birthday)::int
                       ) < CURRENT_DATE
                  THEN INTERVAL '1 year'
                  ELSE INTERVAL '0 year'
                END
            )::date - CURRENT_DATE
          )::int AS "daysUntil"
        FROM members
        WHERE deleted_at IS NULL
          AND is_active = true
          AND birthday IS NOT NULL
          AND birthday_notifications_opt_out = false
      )
      SELECT * FROM upcoming
      WHERE "daysUntil" <= ${daysAhead}
      ORDER BY "daysUntil" ASC
    `;
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  async create(dto: CreateMemberDto, actorUserId: string) {
    this.assertNotJustPassing(dto);

    if (dto.email) {
      await this.assertEmailAvailable(dto.email);
    }

    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }

    const member = await this.prisma.$transaction(async (tx) => {
      const created = await tx.member.create({
        data: {
          ...this.toPersistence(dto),
          // Une date d'arrivée est indispensable au suivi des nouveaux venus :
          // sans elle, la fenêtre de 90 jours ne peut pas être calculée.
          newcomerJoinDate: dto.isNewComer
            ? this.toDate(dto.newcomerJoinDate) ?? new Date()
            : this.toDate(dto.newcomerJoinDate),
        } as Prisma.MemberUncheckedCreateInput,
        select: LIST_SELECT,
      });

      // Le rattachement au département principal est doublé dans
      // `department_members` : c'est cette table qui porte les rôles et que
      // consultent les vérifications de permission.
      if (dto.departmentId) {
        await tx.departmentMember.create({
          data: {
            departmentId: dto.departmentId,
            memberId: created.id,
            role: 'member',
            isMain: true,
          },
        });
      }

      // Trace historique de l'arrivée, conservée même si le membre cesse
      // ensuite d'être « nouveau venu ».
      if (dto.isNewComer) {
        await tx.newComer.create({
          data: {
            memberId: created.id,
            firstName: created.firstName,
            lastName: created.lastName,
            email: dto.email ?? null,
            phone: dto.phone ?? null,
            newcomerJoinDate: this.toDate(dto.newcomerJoinDate) ?? new Date(),
            newcomerIntention: dto.newcomerIntention ?? null,
            createdBy: actorUserId,
          },
        });
      }

      return created;
    });

    this.logger.log(`Membre créé : ${member.firstName} ${member.lastName}`);

    return this.withComputedFields(member);
  }

  async update(id: string, dto: UpdateMemberDto) {
    const existing = await this.prisma.member.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, email: true, departmentId: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    this.assertNotJustPassing(dto);

    if (dto.email && dto.email !== existing.email) {
      await this.assertEmailAvailable(dto.email, id);
    }

    if (dto.departmentId && dto.departmentId !== existing.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }

    const updated = await this.prisma.member.update({
      where: { id },
      data: this.toPersistence(dto),
      select: LIST_SELECT,
    });

    return this.withComputedFields(updated);
  }

  /**
   * Suppression logique.
   *
   * La ligne est conservée : les présences, dons et tâches historiques y font
   * référence. Une suppression physique casserait la comptabilité et les
   * rapports antérieurs.
   *
   * Le compte de connexion associé est désactivé dans le même mouvement —
   * laisser un accès actif à une fiche supprimée serait une faille.
   */
  async remove(id: string) {
    const member = await this.prisma.member.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, firstName: true, lastName: true, user: { select: { id: true } } },
    });

    if (!member) {
      throw this.notFound(id);
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.member.update({
        where: { id },
        data: { deletedAt: new Date(), isActive: false },
      });

      if (member.user) {
        await tx.user.update({
          where: { id: member.user.id },
          data: { isActive: false },
        });

        await tx.refreshToken.updateMany({
          where: { userId: member.user.id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
      }
    });

    this.logger.log(`Membre supprimé : ${member.firstName} ${member.lastName}`);

    return { message: 'Membre supprimé.', id };
  }

  async restore(id: string) {
    const member = await this.prisma.member.findFirst({
      where: { id, deletedAt: { not: null } },
      select: { id: true },
    });

    if (!member) {
      throw new NotFoundException({
        message: 'Aucun membre supprimé ne correspond à cet identifiant.',
        code: 'MEMBER_NOT_DELETED',
      });
    }

    const restored = await this.prisma.member.update({
      where: { id },
      data: { deletedAt: null, isActive: true },
      select: LIST_SELECT,
    });

    return this.withComputedFields(restored);
  }

  // ===========================================================================
  // Départements
  // ===========================================================================

  /**
   * Rattache un membre à un département.
   *
   * Si le rattachement est marqué principal, l'ancien département principal
   * est dégradé et `members.department_id` suit. Les deux représentations —
   * la colonne sur `members` et le drapeau `is_main` — doivent rester
   * cohérentes, faute de quoi l'interface afficherait un département et les
   * permissions en utiliseraient un autre.
   */
  async addToDepartment(memberId: string, dto: AddToDepartmentDto) {
    await this.assertMemberExists(memberId);
    await this.assertDepartmentExists(dto.departmentId);

    const duplicate = await this.prisma.departmentMember.findUnique({
      where: {
        departmentId_memberId: {
          departmentId: dto.departmentId,
          memberId,
        },
      },
      select: { id: true },
    });

    if (duplicate) {
      throw new ConflictException({
        message: 'Ce membre appartient déjà à ce département.',
        code: 'ALREADY_IN_DEPARTMENT',
      });
    }

    return this.prisma.$transaction(async (tx) => {
      if (dto.isMain) {
        await tx.departmentMember.updateMany({
          where: { memberId, isMain: true },
          data: { isMain: false },
        });

        await tx.member.update({
          where: { id: memberId },
          data: { departmentId: dto.departmentId },
        });
      }

      return tx.departmentMember.create({
        data: {
          memberId,
          departmentId: dto.departmentId,
          role: dto.role ?? 'member',
          isMain: dto.isMain ?? false,
        },
        include: { department: { select: { id: true, name: true } } },
      });
    });
  }

  async removeFromDepartment(memberId: string, departmentId: string) {
    const membership = await this.prisma.departmentMember.findUnique({
      where: { departmentId_memberId: { departmentId, memberId } },
      select: { id: true, isMain: true },
    });

    if (!membership) {
      throw new NotFoundException({
        message: "Ce membre n'appartient pas à ce département.",
        code: 'NOT_IN_DEPARTMENT',
      });
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.departmentMember.delete({ where: { id: membership.id } });

      // Retirer le département principal laisserait une référence orpheline
      // sur la fiche membre.
      if (membership.isMain) {
        await tx.member.update({
          where: { id: memberId },
          data: { departmentId: null },
        });
      }
    });

    return { message: 'Membre retiré du département.' };
  }

  // ===========================================================================
  // Graduation des nouveaux venus
  // ===========================================================================

  /**
   * Retire le statut de nouveau venu si le seuil de présence est atteint.
   *
   * Règle métier : neuf présences ou plus sur les quatre-vingt-dix derniers
   * jours. Les valeurs sont configurables, mais correspondent par défaut à
   * celles de la fonction PostgreSQL `check_and_update_new_comer_status`
   * qu'elle remplace.
   *
   * Appelée après chaque enregistrement de présence.
   */
  async checkNewcomerGraduation(memberId: string): Promise<boolean> {
    const member = await this.prisma.member.findFirst({
      where: { id: memberId, isNewComer: true, ...NOT_DELETED },
      select: { id: true, firstName: true, lastName: true },
    });

    // Rien à faire si la personne n'est pas — ou plus — nouvelle venue.
    if (!member) {
      return false;
    }

    const threshold = this.config.get('business.newcomerGraduationAttendances', {
      infer: true,
    });
    const windowDays = this.config.get('business.newcomerGraduationWindowDays', {
      infer: true,
    });

    const since = new Date();
    since.setDate(since.getDate() - windowDays);

    const attendances = await this.prisma.churchAttendance.count({
      where: {
        memberId,
        serviceDate: { gte: since },
        // Une absence enregistrée ne compte évidemment pas comme une présence.
        attendanceType: { in: ['onsite', 'online'] },
        ...NOT_DELETED,
      },
    });

    if (attendances < threshold) {
      return false;
    }

    await this.prisma.member.update({
      where: { id: memberId },
      data: { isNewComer: false },
    });

    this.logger.log(
      `${member.firstName} ${member.lastName} n'est plus nouveau venu ` +
        `(${attendances} présences sur ${windowDays} jours).`,
    );

    return true;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private buildWhere(query: FindMembersDto): Prisma.MemberWhereInput {
    const where: Prisma.MemberWhereInput = { ...NOT_DELETED };

    // Par défaut on ne montre que les membres actifs : les inactifs sont des
    // cas particuliers qu'il faut demander explicitement.
    where.isActive = query.isActive ?? true;

    if (query.role) where.role = query.role;
    if (query.gender) where.gender = query.gender;
    if (query.profession) where.profession = query.profession;
    if (query.isNewComer !== undefined) where.isNewComer = query.isNewComer;
    if (query.newcomerIntention) where.newcomerIntention = query.newcomerIntention;

    // Le département est cherché dans les appartenances plutôt que sur la
    // colonne `departmentId` : un membre peut appartenir à plusieurs
    // départements sans que ce soit son principal.
    if (query.departmentId) {
      where.departmentMembers = { some: { departmentId: query.departmentId } };
    }

    if (query.hasAccount !== undefined) {
      where.user = query.hasAccount ? { isNot: null } : { is: null };
    }

    if (query.search) {
      const term = query.search;
      where.OR = [
        { firstName: { contains: term, mode: 'insensitive' } },
        { lastName: { contains: term, mode: 'insensitive' } },
        { email: { contains: term, mode: 'insensitive' } },
        { phone: { contains: term } },
      ];
    }

    // Un âge minimum correspond à une date de naissance ANTÉRIEURE : plus on
    // est âgé, plus la date est ancienne. L'inversion est volontaire.
    if (query.minAge !== undefined || query.maxAge !== undefined) {
      const birthday: Prisma.DateTimeFilter = {};

      if (query.minAge !== undefined) {
        const latest = new Date();
        latest.setFullYear(latest.getFullYear() - query.minAge);
        birthday.lte = latest;
      }

      if (query.maxAge !== undefined) {
        const earliest = new Date();
        earliest.setFullYear(earliest.getFullYear() - query.maxAge - 1);
        birthday.gte = earliest;
      }

      where.birthday = birthday;
    }

    return where;
  }

  private toPersistence(dto: CreateMemberDto | UpdateMemberDto) {
    const { birthday, newcomerJoinDate, keySkills, ...rest } = dto;

    return {
      ...rest,
      ...(birthday !== undefined ? { birthday: this.toDate(birthday) } : {}),
      ...(newcomerJoinDate !== undefined
        ? { newcomerJoinDate: this.toDate(newcomerJoinDate) }
        : {}),
      // Un tableau Prisma ne peut pas valoir `null` : l'absence de compétences
      // se représente par une liste vide.
      //
      // Le champ est omis quand rien n'est fourni plutôt que forcé à `[]` :
      // à la création, Prisma applique la valeur par défaut du schéma ; à la
      // mise à jour, la liste existante est conservée au lieu d'être écrasée
      // par une modification qui ne la concernait pas.
      ...(keySkills != null ? { keySkills } : {}),
    };
  }

  private toDate(value: string | null | undefined): Date | null {
    if (!value) return null;
    return new Date(value);
  }

  /** Ajoute l'âge, calculé à la volée plutôt que stocké. */
  private withComputedFields<T extends { birthday?: Date | null }>(member: T) {
    return { ...member, age: this.computeAge(member.birthday) };
  }

  private computeAge(birthday: Date | null | undefined): number | null {
    if (!birthday) return null;

    const today = new Date();
    let age = today.getFullYear() - birthday.getFullYear();

    // L'anniversaire n'est pas encore passé cette année.
    const monthDiff = today.getMonth() - birthday.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthday.getDate())) {
      age -= 1;
    }

    return age;
  }

  /**
   * Refuse l'enregistrement d'une personne « de passage » comme membre.
   *
   * Règle métier explicite du guide utilisateur : ces personnes relèvent des
   * visiteurs. Les inscrire comme membres fausserait les effectifs et les
   * statistiques de fidélisation.
   */
  private assertNotJustPassing(dto: CreateMemberDto | UpdateMemberDto): void {
    if (dto.newcomerIntention === 'just_passing') {
      throw new BadRequestException({
        message:
          'Une personne de passage ne peut pas être enregistrée comme membre. ' +
          'Créez plutôt un visiteur.',
        code: 'JUST_PASSING_MUST_BE_VISITOR',
      });
    }
  }

  private async assertEmailAvailable(email: string, excludeId?: string): Promise<void> {
    const existing = await this.prisma.member.findFirst({
      where: {
        email,
        ...NOT_DELETED,
        ...(excludeId ? { id: { not: excludeId } } : {}),
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException({
        message: 'Un membre utilise déjà cette adresse e-mail.',
        code: 'MEMBER_EMAIL_TAKEN',
      });
    }
  }

  private async assertDepartmentExists(departmentId: string): Promise<void> {
    const department = await this.prisma.department.findFirst({
      where: { id: departmentId, ...NOT_DELETED },
      select: { id: true },
    });

    if (!department) {
      throw new NotFoundException({
        message: 'Département introuvable.',
        code: 'DEPARTMENT_NOT_FOUND',
      });
    }
  }

  private async assertMemberExists(id: string): Promise<void> {
    const member = await this.prisma.member.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!member) {
      throw this.notFound(id);
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun membre ne correspond à l'identifiant ${id}.`,
      code: 'MEMBER_NOT_FOUND',
    });
  }
}