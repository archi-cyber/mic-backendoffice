import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * Politique de mot de passe.
 *
 * Huit caractères avec au moins une minuscule, une majuscule et un chiffre.
 * Les caractères spéciaux ne sont pas imposés : cette contrainte pousse en
 * pratique les utilisateurs vers des variantes prévisibles (« Motdepasse1! »)
 * sans gain réel, et complique la saisie sur clavier mobile.
 */
const PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
const PASSWORD_MESSAGE =
  'Le mot de passe doit contenir au moins 8 caractères, dont une minuscule, une majuscule et un chiffre.';

/** Normalise une adresse e-mail saisie. */
const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

// -----------------------------------------------------------------------------

export class LoginDto {
  @ApiProperty({ example: 'responsable@eglise.org' })
  @Transform(normalizeEmail)
  @IsEmail({}, { message: "Adresse e-mail invalide." })
  email!: string;

  @ApiProperty({ example: 'Password123' })
  @IsString()
  @IsNotEmpty({ message: 'Le mot de passe est requis.' })
  // Aucune contrainte de format à la connexion : la valider reviendrait à
  // révéler la politique en vigueur, et bloquerait les comptes créés sous une
  // politique antérieure.
  @MaxLength(128)
  password!: string;

  @ApiPropertyOptional({
    example: 'iPhone 14 — iOS 18',
    description: "Identification de l'appareil, affichée dans la liste des sessions",
  })
  @IsString()
  @MaxLength(255)
  deviceInfo?: string;
}

// -----------------------------------------------------------------------------

export class RefreshTokenDto {
  @ApiProperty({ description: 'Jeton de rafraîchissement obtenu à la connexion' })
  @IsString()
  @IsNotEmpty({ message: 'Le jeton de rafraîchissement est requis.' })
  refreshToken!: string;
}

// -----------------------------------------------------------------------------

export class ChangePasswordDto {
  @ApiProperty({ description: 'Mot de passe actuel' })
  @IsString()
  @IsNotEmpty({ message: 'Le mot de passe actuel est requis.' })
  currentPassword!: string;

  @ApiProperty({ example: 'NouveauMotDePasse2026' })
  @IsString()
  @MinLength(8, { message: PASSWORD_MESSAGE })
  @MaxLength(128)
  @Matches(PASSWORD_PATTERN, { message: PASSWORD_MESSAGE })
  newPassword!: string;
}

// -----------------------------------------------------------------------------

export class ForgotPasswordDto {
  @ApiProperty({ example: 'responsable@eglise.org' })
  @Transform(normalizeEmail)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email!: string;
}

// -----------------------------------------------------------------------------

export class ResetPasswordDto {
  @ApiProperty({ example: 'responsable@eglise.org' })
  @Transform(normalizeEmail)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email!: string;

  @ApiProperty({ description: 'Jeton reçu par e-mail' })
  @IsString()
  @IsNotEmpty({ message: 'Le jeton est requis.' })
  token!: string;

  @ApiProperty({ example: 'NouveauMotDePasse2026' })
  @IsString()
  @MinLength(8, { message: PASSWORD_MESSAGE })
  @MaxLength(128)
  @Matches(PASSWORD_PATTERN, { message: PASSWORD_MESSAGE })
  newPassword!: string;
}