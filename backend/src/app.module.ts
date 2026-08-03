import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { PermissionsGuard } from './common/guards/permissions.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import configuration from './config/configuration';
import { envValidationSchema } from './config/env.validation';
import { HealthController } from './health.controller';
import { AuthModule } from './modules/auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validationSchema: envValidationSchema,
      validationOptions: { abortEarly: false, allowUnknown: true },
      cache: true,
      envFilePath: ['.env.local', '.env'],
    }),

    PrismaModule,
    ScheduleModule.forRoot(),

    ThrottlerModule.forRoot([
      { name: 'default', ttl: 60_000, limit: 120 },
      { name: 'strict', ttl: 60_000, limit: 5 },
    ]),

    // --- Modules metier ---
    AuthModule,
    // Phase 3 : MembersModule, DepartmentsModule, UsersModule
    // Phase 4 : ChurchServicesModule, ChurchAttendanceModule, VisitorsModule
    // Phase 5 : TasksModule, ProjectsModule, TagsModule, PenaltiesModule
    // Phase 6 : TeachingsModule, ClassesModule, EventsModule
    // Phase 7 : GivingModule, AnnouncementsModule, NotificationsModule
    // Phase 8 : ReportsModule
    // Phase 9 : RealtimeModule
  ],

  controllers: [HealthController],

  providers: [
    // --- Filtres d'exception ---
    // NestJS consulte les filtres du dernier declare au premier :
    // PrismaExceptionFilter, plus specifique, doit donc venir apres.
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_FILTER, useClass: PrismaExceptionFilter },

    { provide: APP_INTERCEPTOR, useClass: TransformInterceptor },

    // --- Chaine de securite ---
    // L'ordre de declaration est l'ordre d'execution. Chaque maillon suppose
    // le precedent satisfait :
    //   1. ThrottlerGuard    - limite le debit avant tout travail couteux
    //   2. JwtAuthGuard      - etablit l'identite
    //   3. RolesGuard        - verifie le niveau de privilege
    //   4. PermissionsGuard  - verifie le droit sur le module concerne
    //
    // Toute route est protegee par defaut. @Public() est l'exception
    // explicite : c'est le sens sur, puisqu'un oubli rend la route
    // inaccessible plutot que publique.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
  ],
})
export class AppModule {}