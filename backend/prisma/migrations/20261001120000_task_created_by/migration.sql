-- Auteur d'une tâche : un adjoint de département ne peut supprimer que les
-- tâches qu'il a créées (règle reprise de mic_backoffice v1.0.11).
ALTER TABLE "tasks" ADD COLUMN "created_by" UUID;

CREATE INDEX "tasks_created_by_idx" ON "tasks"("created_by");

ALTER TABLE "tasks"
  ADD CONSTRAINT "tasks_created_by_fkey"
  FOREIGN KEY ("created_by") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
