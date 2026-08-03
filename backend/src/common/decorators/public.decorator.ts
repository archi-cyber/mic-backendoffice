import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Rend une route accessible sans jeton.
 *
 * `JwtAuthGuard` étant appliqué globalement, toute route est protégée par
 * défaut. Ce décorateur est l'exception explicite — réservée à la connexion,
 * au rafraîchissement et à la réinitialisation de mot de passe.
 *
 * Le sens de la règle est important : oublier `@Public()` rend une route
 * inaccessible, ce qui se voit immédiatement. L'inverse — oublier de protéger
 * une route — passerait inaperçu jusqu'à la fuite de données.
 *
 * @example
 *   @Public()
 *   @Post('login')
 *   login(@Body() dto: LoginDto) { ... }
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);