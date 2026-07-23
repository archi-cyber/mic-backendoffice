"""Fill untranslated fr/es entries in app_localizations.dart _literalValues."""
from __future__ import annotations

import re
from pathlib import Path

PATH = Path(
    r"c:\Users\maint\Documents\Valdo\work\Molded\mic_backoffice"
    r"\lib\core\localization\app_localizations.dart"
)

# Load extra translations from a simple TSV if present: en\tfr\tes
EXTRA = Path(
    r"c:\Users\maint\Documents\Valdo\work\Molded\mic_backoffice"
    r"\tools\_i18n_extra.tsv"
)

# Built-in map: English -> (French, Spanish)
FR_ES: dict[str, tuple[str, str]] = {
    "Absent": ("Absent", "Ausente"),
    "Backoffice": ("Backoffice", "Backoffice"),
    "Date": ("Date", "Fecha"),
    "Description": ("Description", "Descripción"),
    "Intention": ("Intention", "Intención"),
    "Notes": ("Notes", "Notas"),
    "(Optional)": ("(Facultatif)", "(Opcional)"),
    "Actions": ("Actions", "Acciones"),
    "Active": ("Actif", "Activo"),
    "Activity Logs": ("Journaux d'activité", "Registros de actividad"),
    "Add Department": ("Ajouter un département", "Agregar departamento"),
    "Add First Record": ("Ajouter le premier enregistrement", "Agregar primer registro"),
    "Add Giving Record": ("Ajouter une offrande", "Agregar ofrenda"),
    "Add Listener": ("Ajouter un auditeur", "Agregar oyente"),
    "Add Member": ("Ajouter un membre", "Agregar miembro"),
    "Add Members": ("Ajouter des membres", "Agregar miembros"),
    "Add Members to Training": (
        "Ajouter des membres à la formation",
        "Agregar miembros a la formación",
    ),
    "Add Task": ("Ajouter une tâche", "Agregar tarea"),
    "Add Visitor": ("Ajouter un visiteur", "Agregar visitante"),
    "Add skill": ("Ajouter une compétence", "Agregar habilidad"),
    "Add task": ("Ajouter une tâche", "Agregar tarea"),
    "Additional comments or notes (optional)": (
        "Commentaires ou notes supplémentaires (facultatif)",
        "Comentarios o notas adicionales (opcional)",
    ),
    "Address": ("Adresse", "Dirección"),
    "Admin": ("Admin", "Admin"),
    "Admin Panel": ("Panneau d'administration", "Panel de administración"),
    "All church services": ("Tous les cultes", "Todos los cultos"),
    "All members are already enrolled in this class": (
        "Tous les membres sont déjà inscrits à cette formation",
        "Todos los miembros ya están inscritos en esta clase",
    ),
    "Announcement created successfully": (
        "Annonce créée avec succès",
        "Anuncio creado correctamente",
    ),
    "Apply": ("Appliquer", "Aplicar"),
    "Are you sure you want to delete this event?": (
        "Voulez-vous vraiment supprimer cet événement ?",
        "¿Está seguro de que desea eliminar este evento?",
    ),
    "Are you sure you want to remove this registration?": (
        "Voulez-vous vraiment supprimer cette inscription ?",
        "¿Está seguro de que desea eliminar este registro?",
    ),
    "Assignee filter": ("Filtre d'assigné", "Filtro de asignado"),
    "At least email or phone is required": (
        "Au moins l'e-mail ou le téléphone est requis",
        "Se requiere al menos correo o teléfono",
    ),
    "Attendance": ("Présence", "Asistencia"),
    "Attendance Trend": ("Tendance de présence", "Tendencia de asistencia"),
    "Avg attendance": ("Présence moyenne", "Asistencia promedio"),
    "Basic information": ("Informations de base", "Información básica"),
    "Birthday": ("Anniversaire", "Cumpleaños"),
    "Birthday *": ("Anniversaire *", "Cumpleaños *"),
    "Change Password": ("Changer le mot de passe", "Cambiar contraseña"),
    "Choose from gallery": ("Choisir depuis la galerie", "Elegir de la galería"),
    "Church Attendance": ("Présence au culte", "Asistencia al culto"),
    "Church service": ("Culte", "Culto"),
    "City": ("Ville", "Ciudad"),
    "Clear All": ("Tout effacer", "Borrar todo"),
    "Comments": ("Commentaires", "Comentarios"),
    "Contact": ("Contact", "Contacto"),
    "Could not create task": ("Impossible de créer la tâche", "No se pudo crear la tarea"),
    "Could not move task": ("Impossible de déplacer la tâche", "No se pudo mover la tarea"),
    "Could not pick photo: $e": (
        "Impossible de sélectionner la photo : $e",
        "No se pudo elegir la foto: $e",
    ),
    "Could not update assignment": (
        "Impossible de mettre à jour l'assignation",
        "No se pudo actualizar la asignación",
    ),
    "Could not update tags": (
        "Impossible de mettre à jour les étiquettes",
        "No se pudieron actualizar las etiquetas",
    ),
    "Country": ("Pays", "País"),
    "Create User": ("Créer un utilisateur", "Crear usuario"),
    "Create a department and attach reference documents": (
        "Créez un département et joignez des documents de référence",
        "Cree un departamento y adjunte documentos de referencia",
    ),
    "Create tag": ("Créer une étiquette", "Crear etiqueta"),
    "Created": ("Créé", "Creado"),
    "Daily presence": ("Présence journalière", "Presencia diaria"),
    "Delete": ("Supprimer", "Eliminar"),
    "Department": ("Département", "Departamento"),
    "Department name is required": (
        "Le nom du département est requis",
        "El nombre del departamento es obligatorio",
    ),
    "Documents (Optional)": ("Documents (facultatif)", "Documentos (opcional)"),
    "Done": ("Terminé", "Hecho"),
    "Due date": ("Date d'échéance", "Fecha de vencimiento"),
    "Edit": ("Modifier", "Editar"),
    "Edit Attendance": ("Modifier la présence", "Editar asistencia"),
    "Edit Record": ("Modifier l'enregistrement", "Editar registro"),
    "Edit tag": ("Modifier l'étiquette", "Editar etiqueta"),
    "Email": ("E-mail", "Correo"),
    "Email Sent!": ("E-mail envoyé !", "¡Correo enviado!"),
    "Enter a descriptive title for this report": (
        "Saisissez un titre descriptif pour ce rapport",
        "Introduzca un título descriptivo para este informe",
    ),
    "Enter the name of the department": (
        "Saisissez le nom du département",
        "Introduzca el nombre del departamento",
    ),
    "Error": ("Erreur", "Error"),
    "Error adding members": (
        "Erreur lors de l'ajout des membres",
        "Error al agregar miembros",
    ),
    "Event Sessions": ("Sessions d'événement", "Sesiones del evento"),
    "Export PDF": ("Exporter PDF", "Exportar PDF"),
    "Export all data to JSON file": (
        "Exporter toutes les données en fichier JSON",
        "Exportar todos los datos a un archivo JSON",
    ),
    "Failed to change language: $e": (
        "Échec du changement de langue : $e",
        "Error al cambiar el idioma: $e",
    ),
    "Failed to update notifications: $e": (
        "Échec de la mise à jour des notifications : $e",
        "Error al actualizar las notificaciones: $e",
    ),
    "Filter": ("Filtrer", "Filtrar"),
    "First name is required": ("Le prénom est requis", "El nombre es obligatorio"),
    "Generate PDF": ("Générer le PDF", "Generar PDF"),
    "Generate Report": ("Générer le rapport", "Generar informe"),
    "Invalid email format": ("Format d'e-mail invalide", "Formato de correo inválido"),
    "Just now": ("À l'instant", "Justo ahora"),
    "Key Skills": ("Compétences clés", "Habilidades clave"),
    "Last name is required": ("Le nom est requis", "El apellido es obligatorio"),
    "Leader": ("Responsable", "Líder"),
    "Loading...": ("Chargement...", "Cargando..."),
    "Manage Projects": ("Gérer les projets", "Gestionar proyectos"),
    "Manage Tags": ("Gérer les étiquettes", "Gestionar etiquetas"),
    "Manage Tasks": ("Gérer les tâches", "Gestionar tareas"),
    "Mark Attendance": ("Marquer la présence", "Marcar asistencia"),
    "Member added successfully": (
        "Membre ajouté avec succès",
        "Miembro agregado correctamente",
    ),
    "Member is required": ("Le membre est requis", "El miembro es obligatorio"),
    "Members": ("Membres", "Miembros"),
    "No active members found": (
        "Aucun membre actif trouvé",
        "No se encontraron miembros activos",
    ),
    "No attendance recorded for this service": (
        "Aucune présence enregistrée pour ce culte",
        "No hay asistencia registrada para este culto",
    ),
    "No data available": ("Aucune donnée disponible", "No hay datos disponibles"),
    "No departments assigned": (
        "Aucun département assigné",
        "No hay departamentos asignados",
    ),
    "No files uploaded": ("Aucun fichier téléversé", "No hay archivos subidos"),
    "No giving records yet": (
        "Aucun enregistrement d'offrande pour le moment",
        "Aún no hay registros de ofrendas",
    ),
    "No leaders found": ("Aucun responsable trouvé", "No se encontraron líderes"),
    "No results found": ("Aucun résultat", "No se encontraron resultados"),
    "Optional description for the department": (
        "Description facultative du département",
        "Descripción opcional del departamento",
    ),
    "Page {current} of {total}": (
        "Page {current} sur {total}",
        "Página {current} de {total}",
    ),
    "Password Reset Successful!": (
        "Réinitialisation du mot de passe réussie !",
        "¡Restablecimiento de contraseña exitoso!",
    ),
    "Password must be at least 6 characters": (
        "Le mot de passe doit contenir au moins 6 caractères",
        "La contraseña debe tener al menos 6 caracteres",
    ),
    "Passwords do not match": (
        "Les mots de passe ne correspondent pas",
        "Las contraseñas no coinciden",
    ),
    "Phone": ("Téléphone", "Teléfono"),
    "Please enter announcement message": (
        "Veuillez saisir le message de l'annonce",
        "Introduzca el mensaje del anuncio",
    ),
    "Please enter announcement title": (
        "Veuillez saisir le titre de l'annonce",
        "Introduzca el título del anuncio",
    ),
    "Please enter event title": (
        "Veuillez saisir le titre de l'événement",
        "Introduzca el título del evento",
    ),
    "Present": ("Présent", "Presente"),
    "Project (optional)": ("Projet (facultatif)", "Proyecto (opcional)"),
    "Quick actions": ("Actions rapides", "Acciones rápidas"),
    "Register Guest": ("Inscrire un invité", "Registrar invitado"),
    "Register for Event": ("S'inscrire à l'événement", "Registrarse al evento"),
    "Remove": ("Retirer", "Quitar"),
    "Required": ("Obligatoire", "Obligatorio"),
    "Reset Password": ("Réinitialiser le mot de passe", "Restablecer contraseña"),
    "Role Assignment": ("Attribution des rôles", "Asignación de roles"),
    "Save Attendance": ("Enregistrer la présence", "Guardar asistencia"),
    "Select Service Date": (
        "Sélectionner la date du culte",
        "Seleccionar fecha del culto",
    ),
    "Select a member": ("Sélectionner un membre", "Seleccionar un miembro"),
    "Select due date (optional)": (
        "Sélectionner la date d'échéance (facultatif)",
        "Seleccionar fecha de vencimiento (opcional)",
    ),
    "Service Details": ("Détails du culte", "Detalles del culto"),
    "Service name": ("Nom du service", "Nombre del servicio"),
    "Service name is required": (
        "Le nom du service est requis",
        "El nombre del servicio es obligatorio",
    ),
    "Service schedule": ("Planning des services", "Horario de servicios"),
    "Set Main Department": (
        "Définir le département principal",
        "Establecer departamento principal",
    ),
    "Set New Password": (
        "Définir un nouveau mot de passe",
        "Establecer nueva contraseña",
    ),
    "Sign out of your account": (
        "Se déconnecter de votre compte",
        "Cerrar sesión de su cuenta",
    ),
    "Tags (optional)": ("Étiquettes (facultatif)", "Etiquetas (opcional)"),
    "Task Completion": ("Achèvement des tâches", "Finalización de tareas"),
    "Task details": ("Détails de la tâche", "Detalles de la tarea"),
    "Task title is required": (
        "Le titre de la tâche est requis",
        "El título de la tarea es obligatorio",
    ),
    "Tasks": ("Tâches", "Tareas"),
    "This month": ("Ce mois", "Este mes"),
    "Token is required": ("Le jeton est requis", "El token es obligatorio"),
    "Total": ("Total", "Total"),
    "Total Giving": ("Total des offrandes", "Total de ofrendas"),
    "Training name is required": (
        "Le nom de la formation est requis",
        "El nombre de la formación es obligatorio",
    ),
    "Try adjusting search or filters": (
        "Essayez d'ajuster la recherche ou les filtres",
        "Intente ajustar la búsqueda o los filtros",
    ),
    "Type a tag and add": (
        "Saisissez une étiquette et ajoutez",
        "Escriba una etiqueta y agregue",
    ),
    "Unregister": ("Désinscrire", "Cancelar registro"),
    "Update": ("Mettre à jour", "Actualizar"),
    "View": ("Voir", "Ver"),
    "Visitors": ("Visiteurs", "Visitantes"),
    "Yesterday": ("Hier", "Ayer"),
    "{count}m ago": ("Il y a {count} min", "Hace {count} min"),
    "{count}h ago": ("Il y a {count} h", "Hace {count} h"),
    "{count}d ago": ("Il y a {count} j", "Hace {count} d"),
}


def escape_dart(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def load_extra() -> None:
    if not EXTRA.exists():
        return
    for line in EXTRA.read_text(encoding="utf-8").splitlines():
        line = line.rstrip("\n")
        if not line or line.startswith("#") or "\t" not in line:
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        en, fr, es = parts[0], parts[1], parts[2]
        FR_ES[en] = (fr, es)
        # Also index without dart escapes for \$ forms
        en_plain = en.replace("\\$", "$").replace("\\${", "${").replace("\\'", "'")
        FR_ES[en_plain] = (fr, es)


def replace_locale_block(text: str, locale: str, index: int) -> tuple[str, int]:
    marker = "'" + locale + "': {"
    start = text.find(marker)
    if start < 0:
        raise SystemExit("Locale block not found: " + locale)
    brace_start = start + len(marker) - 1
    i = brace_start
    depth = 0
    end = -1
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
        i += 1
    if end < 0:
        raise SystemExit("Could not find end of locale block: " + locale)

    block = text[brace_start + 1 : end]
    changed = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal changed
        raw_key = match.group(1)
        raw_val = match.group(2)
        key = raw_key.replace("\\'", "'")
        val = raw_val.replace("\\'", "'")
        # Unescape dart \$ to $ for lookup (source stores \$ for interpolation)
        lookup_key = key.replace("\\$", "$").replace("\\${", "${")
        lookup_val = val.replace("\\$", "$").replace("\\${", "${")
        if lookup_key != lookup_val and key != val:
            return match.group(0)
        # Also treat as untranslated when source key==value including escapes
        if key != val and lookup_key != lookup_val:
            return match.group(0)
        if lookup_key not in FR_ES and key not in FR_ES:
            return match.group(0)
        new_val = FR_ES.get(lookup_key) or FR_ES.get(key)
        if new_val is None:
            return match.group(0)
        translated = new_val[index]
        # Preserve $ placeholders as \$ in dart source
        translated_src = (
            translated.replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("$", "\\$")
        )
        changed += 1
        return "'" + raw_key + "': '" + translated_src + "'"

    # Only update when key equals value in source (untranslated)
    def repl2(match: re.Match[str]) -> str:
        nonlocal changed
        raw_key = match.group(1)
        raw_val = match.group(2)
        if raw_key != raw_val:
            return match.group(0)
        key = raw_key.replace("\\'", "'").replace("\\$", "$").replace("\\${", "${")
        if key not in FR_ES:
            # try with escaped form as in dump file
            if raw_key not in FR_ES:
                return match.group(0)
            translated = FR_ES[raw_key][index]
        else:
            translated = FR_ES[key][index]
        translated_src = (
            translated.replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("$", "\\$")
        )
        changed += 1
        return "'" + raw_key + "': '" + translated_src + "'"

    new_block = re.sub(
        r"'((?:\\'|[^'])*)'\s*:\s*'((?:\\'|[^'])*)'",
        repl2,
        block,
    )
    return text[: brace_start + 1] + new_block + text[end:], changed


def ensure_keys(text: str, locale: str, index: int) -> str:
    extras = [
        "Just now",
        "Yesterday",
        "{count}m ago",
        "{count}h ago",
        "{count}d ago",
        "Please enter event title",
        "Training name is required",
        "Please enter announcement title",
        "Please enter announcement message",
    ]
    marker = "'" + locale + "': {"
    start = text.find(marker)
    brace_start = start + len(marker) - 1
    i = brace_start
    depth = 0
    end = -1
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
        i += 1
    block = text[brace_start + 1 : end]
    insert = ""
    for key in extras:
        needle = "'" + escape_dart(key) + "':"
        if needle not in block and key in FR_ES:
            insert += (
                "\n      '"
                + escape_dart(key)
                + "': '"
                + escape_dart(FR_ES[key][index])
                + "',"
            )
    if not insert:
        return text
    return text[: brace_start + 1] + insert + text[brace_start + 1 :]


def main() -> None:
    load_extra()
    text = PATH.read_text(encoding="utf-8")
    text, c1 = replace_locale_block(text, "fr", 0)
    text, c2 = replace_locale_block(text, "es", 1)
    text = ensure_keys(text, "fr", 0)
    text = ensure_keys(text, "es", 1)
    PATH.write_text(text, encoding="utf-8")
    print(f"Updated fr={c1}, es={c2} entries from map ({len(FR_ES)} keys).")


if __name__ == "__main__":
    main()
