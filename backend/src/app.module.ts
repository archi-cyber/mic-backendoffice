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
import { ChurchModule } from './modules/church/church.module';
import { ClassesModule } from './modules/classes/classes.module';
import { CommunicationsModule } from './modules/communications/communications.module';
import { DepartmentsModule } from './modules/departments/departments.module';
import { EventsModule } from './modules/events/events.module';
import { GivingModule } from './modules/giving/giving.module';
import { MembersModule } from './modules/members/members.module';
import { SundaySchoolModule } from './modules/sunday-school/sunday-school.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { TeachingsModule } from './modules/teachings/teachings.module';
import { UsersModule } from './modules/users/users.module';
import { VisitorsModule } from './modules/visitors/visitors.module';
import { ReportsModule } from './modules/reports/reports.module';
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
    UsersModule,
    MembersModule,
    DepartmentsModule,
    ChurchModule,
    SundaySchoolModule,
    VisitorsModule,
    TasksModule,
    TeachingsModule,
    ClassesModule,
    EventsModule,
    GivingModule,
    CommunicationsModule,
    ReportsModule,
    // Phase 9 : RealtimeModule
  ],

  controllers: [HealthController],

  providers: [
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_FILTER, useClass: PrismaExceptionFilter },

    { provide: APP_INTERCEPTOR, useClass: TransformInterceptor },

    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
  ],
})
export class AppModule {}