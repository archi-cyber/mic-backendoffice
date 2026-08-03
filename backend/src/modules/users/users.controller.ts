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
import { Roles } from '../../common/decorators/roles.decorator';
import {
  CreateUserAccountDto,
  FindUsersDto,
  SetPermissionsDto,
  SetUserActiveDto,
  UpdateUserDto,
} from './dto/user.dto';
import { UsersService } from './users.service';

/**
 * Gestion des comptes de connexion.
 *
 * Tout le controleur est reserve aux administrateurs : creer un compte,
 * changer un role ou accorder des permissions revient a distribuer des droits.
 * Confier cela aux permissions granulaires serait circulaire — un responsable
 * pourrait s auto-attribuer des acces.
 */
@ApiTags('users')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  // ---------------------------------------------------------------------------
  // Comptes
  // ---------------------------------------------------------------------------

  @Get()
  @ApiOperation({ summary: 'Liste des comptes de connexion' })
  findAll(@Query() query: FindUsersDto) {
    return this.users.findAll(query);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Detail d un compte',
    description: 'Inclut les permissions granulaires accordees.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.findOne(id);
  }

  @Post()
  @ApiOperation({
    summary: 'Cree un compte pour un membre',
    description:
      'Le compte recoit le mot de passe par defaut avec changement ' +
      'obligatoire. Aucune permission n est accordee au depart.',
  })
  create(@Body() dto: CreateUserAccountDto) {
    return this.users.createAccount(dto);
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Modifie un compte',
    description:
      'Un changement de role ferme les sessions ouvertes : le nouveau role ' +
      'prend effet a la reconnexion.',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserDto,
  ) {
    return this.users.update(id, dto);
  }

  @Patch(':id/active')
  @ApiOperation({
    summary: 'Active ou desactive un compte',
    description:
      'La desactivation ferme immediatement toutes les sessions. Le dernier ' +
      'administrateur actif ne peut pas etre desactive.',
  })
  setActive(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetUserActiveDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.users.setActive(id, dto.isActive, actorId);
  }

  @Post(':id/reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Reinitialise le mot de passe',
    description:
      'Remet le mot de passe par defaut. Utile quand le membre n a plus ' +
      'acces a son adresse e-mail.',
  })
  forcePasswordReset(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.forcePasswordReset(id);
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Supprime un compte',
    description: 'Suppression logique. La fiche membre est conservee.',
  })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') actorId: string,
  ) {
    return this.users.remove(id, actorId);
  }

  // ---------------------------------------------------------------------------
  // Permissions granulaires
  // ---------------------------------------------------------------------------

  @Get(':id/permissions')
  @ApiOperation({
    summary: 'Grille des permissions',
    description:
      'Renvoie les douze modules, y compris ceux sans droit accorde, pour ' +
      'alimenter le tableau d administration.',
  })
  getPermissions(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.getPermissions(id);
  }

  @Post(':id/permissions')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Remplace les permissions',
    description:
      'Remplacement integral : les modules absents de la liste voient leurs ' +
      'droits revoques.',
  })
  setPermissions(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetPermissionsDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.users.setPermissions(id, dto, actorId);
  }
}