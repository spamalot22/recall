ALTER TABLE "encrypted_records" DROP CONSTRAINT "encrypted_records_pkey";--> statement-breakpoint
ALTER TABLE "encrypted_records" ADD CONSTRAINT "encrypted_records_user_id_id_pk" PRIMARY KEY("user_id","id");
