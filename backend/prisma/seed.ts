/**
 
 * Le script est idempotent : il peut être relancé sans créer de doublon ni
 * écraser un mot de passe déjà changé. C'est essentiel, car il s'exécute
 * potentiellement à chaque déploiement.
 */

import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const ARGON2_OPTIONS: argon2.Options = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
};

/**
 * Départements créés par défaut.
.
 */
const DEFAULT_DEPARTMENTS = [
  { name: 'Finance', description: 'Gestion des dîmes, offrandes et dépenses' },
  { name: 'Média', description: 'Projection, captation vidéo et photographie' },
  { name: 'Louange', description: 'Conduite musicale des cultes' },
  { name: 'Accueil', description: 'Accueil des visiteurs et nouveaux venus' },
  { name: 'Intercession', description: 'Prière et suivi spirituel' },
];

/** Les douze modules soumis à permissions granulaires. */
const FEATURES = [
  'members',
  'departments',
  'trainings',
  'events',
  'tasks',
  'reports',
  'church_attendance',
  'sunday_school_attendance',
  'visitors',
  'giving',
  'chat',
  'teachings',
];

async function main(): Promise<void> {
  console.log('Initialisation des données…\n');

  // ---------------------------------------------------------------------------
  // 1. Paramètres de pénalités
  // ---------------------------------------------------------------------------

  await prisma.taskPenaltySettings.upsert({
    where: { id: 'global' },
    // Aucune mise à jour : si un administrateur a ajusté les montants, le seed
    // ne doit pas les réécrire lors d'un redéploiement.
    update: {},
    create: {
      id: 'global',
      defaultDailyPenaltyAmount: Number(process.env.DEFAULT_DAILY_PENALTY_AMOUNT ?? 100),
      blockingThresholdAmount: Number(process.env.BLOCKING_THRESHOLD_AMOUNT ?? 3_500),
      teachingTaskDueOffsetDays: Number(process.env.TEACHING_TASK_DUE_OFFSET_DAYS ?? 10),
    },
  });
  console.log('  Paramètres de pénalités en place.');

  // ---------------------------------------------------------------------------
  // 2. Départements
  // ---------------------------------------------------------------------------

  let departmentsCreated = 0;
  for (const department of DEFAULT_DEPARTMENTS) {
    const existing = await prisma.department.findFirst({
      where: { name: department.name, deletedAt: null },
      select: { id: true },
    });

    if (!existing) {
      await prisma.department.create({ data: department });
      departmentsCreated += 1;
    }
  }
  console.log(
    `  Départements : ${departmentsCreated} créé(s), ${DEFAULT_DEPARTMENTS.length - departmentsCreated} déjà présent(s).`,
  );

  // ---------------------------------------------------------------------------
  // 3. Compte super-administrateur
  // ---------------------------------------------------------------------------

  const adminEmail = (process.env.SUPER_ADMIN_EMAIL ?? 'admin@systemic.church')
    .trim()
    .toLowerCase();
  const adminPassword = process.env.SUPER_ADMIN_PASSWORD ?? 'ChangeMe2026!';

  const existingAdmin = await prisma.user.findUnique({
    where: { email: adminEmail },
    select: { id: true },
  });

  if (existingAdmin) {
    console.log(`  Administrateur déjà existant : ${adminEmail}`);
  } else {
    // La fiche membre est créée en même temps que le compte : sans elle,
    // l'administrateur n'apparaîtrait dans aucune liste de présence ni
    // d'assignation de tâche.
    const adminMember = await prisma.member.create({
      data: {
        firstName: 'Administrateur',
        lastName: 'Système',
        email: adminEmail,
        role: 'admin',
        isActive: true,
      },
    });

    await prisma.user.create({
      data: {
        email: adminEmail,
        role: 'admin',
        memberId: adminMember.id,
        passwordHash: await argon2.hash(adminPassword, ARGON2_OPTIONS),
        // Force le changement à la première connexion : le mot de passe du
        // seed transite par une variable d'environnement, donc il est
        // potentiellement visible dans les journaux de déploiement.
        mustChangePassword: true,
        isActive: true,
        emailVerifiedAt: new Date(),
      },
    });

    console.log(`  Administrateur créé : ${adminEmail}`);
    console.log('  Changement de mot de passe exigé à la première connexion.');
  }

  // ---------------------------------------------------------------------------
  // 4. Rappel des modules soumis à permissions
  // ---------------------------------------------------------------------------

  console.log(`\n  Modules gérés par leader_access : ${FEATURES.length}`);
  console.log(`  ${FEATURES.join(', ')}`);
  console.log(
    "\n  Aucune permission n'est accordée par défaut. Les administrateurs y",
  );
  console.log('  accèdent de droit ; les responsables devront être habilités.');

  console.log('\nInitialisation terminée.');
}

main()
  .catch((error) => {
    console.error('\nÉchec du seed :', error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());