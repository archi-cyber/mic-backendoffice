import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermission } from '../../common/decorators/permission.decorator';
import { FEATURES, type AuthenticatedUser } from '../auth/types/auth.types';
import { AnnouncementsService } from './announcements.service';
import {
  CreateAnnouncementDto,
  FindAnnouncementsDto,
  FindNotificationsDto,
  MarkNotificationsReadDto,
  UpdateAnnouncementDto,
} from './dto/communication.dto';
import { NotificationsService } from './notifications.service';

// =============================================================================
// ANNONCES
// =============================================================================

@ApiTags('chat')
@ApiBearerAuth('access-token')
@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}

  @Get()
  @RequirePermission(FEATURES.chat, 'view')
  @ApiOperation({
    summary: 'Annonces visibles',
    description:
      'Cumule les annonces globales, celles des departements de l utilisateur ' +
      'et celles qui le visent nommement. Un administrateur voit tout.',
  })
  findAll(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: FindAnnouncementsDto,
  ) {
    return this.announcements.findVisible(user, query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.chat, 'view')
  @ApiOperation({ summary: 'Detail d une annonce' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.announcements.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.chat, 'create')
  @ApiOperation({
    summary: 'Publie une annonce',
    description:
      'Trois portees possibles : globale, departementale, ou ciblee sur des ' +
      'membres. Les destinataires recoivent une notification.',
  })
  create(
    @Body() dto: CreateAnnouncementDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.announcements.create(dto, userId);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.chat, 'edit')
  @ApiOperation({
    summary: 'Modifie une annonce',
    description: 'Reserve a l auteur ou a un administrateur.',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAnnouncementDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.announcements.update(id, dto, user);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.chat, 'delete')
  @ApiOperation({ summary: 'Supprime une annonce' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.announcements.remove(id, user);
  }
}

// =============================================================================
// NOTIFICATIONS
// =============================================================================

/**
 * Notifications personnelles.
 *
 * Aucune permission granulaire n est requise : chacun accede a ses propres
 * notifications, et seulement aux siennes. Le filtrage se fait sur le memberId
 * du compte connecte, jamais sur un parametre fourni par le client.
 */
@ApiTags('notifications')
@ApiBearerAuth('access-token')
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOperation({
    summary: 'Mes notifications',
    description:
      'Inclut les notifications destinees a toute l assemblee. Le compteur ' +
      'unreadCount figure dans meta.',
  })
  findMine(
    @CurrentUser('memberId') memberId: string | null,
    @Query() query: FindNotificationsDto,
  ) {
    if (!memberId) {
      return {
        data: [],
        meta: { page: 1, limit: 0, total: 0, totalPages: 1, unreadCount: 0 },
      };
    }
    return this.notifications.findForMember(memberId, query);
  }

  @Get('unread-count')
  @ApiOperation({
    summary: 'Nombre de notifications non lues',
    description: 'Route legere, destinee au badge de l interface.',
  })
  async countUnread(@CurrentUser('memberId') memberId: string | null) {
    return { count: memberId ? await this.notifications.countUnread(memberId) : 0 };
  }

  @Post('read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Marque des notifications comme lues',
    description: 'Sans liste d identifiants, toutes le sont.',
  })
  markAsRead(
    @CurrentUser('memberId') memberId: string | null,
    @Body() dto: MarkNotificationsReadDto,
  ) {
    if (!memberId) {
      return { message: 'Aucune notification.', updated: 0, unreadCount: 0 };
    }
    return this.notifications.markAsRead(memberId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Supprime une de mes notifications' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('memberId') memberId: string | null,
  ) {
    if (!memberId) {
      return { message: 'Aucune notification.', id };
    }
    return this.notifications.remove(id, memberId);
  }
}