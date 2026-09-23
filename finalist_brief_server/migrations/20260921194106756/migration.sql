BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "brief" (
    "id" bigserial PRIMARY KEY,
    "status" text NOT NULL,
    "mode" text NOT NULL,
    "progressPercent" bigint NOT NULL,
    "progressMessage" text NOT NULL,
    "stageLog" json NOT NULL,
    "submissionCount" bigint NOT NULL,
    "segments" json,
    "videoUrl" text,
    "videoDurationSec" bigint,
    "createdAt" timestamp without time zone NOT NULL,
    "completedAt" timestamp without time zone
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "submission" (
    "id" bigserial PRIMARY KEY,
    "slug" text NOT NULL,
    "title" text NOT NULL,
    "creator" text NOT NULL,
    "summary" text NOT NULL,
    "gemmaUse" text NOT NULL,
    "kaggleUrl" text NOT NULL,
    "repoUrl" text,
    "demoUrl" text,
    "hasDemoVideo" boolean NOT NULL,
    "coverAsset" text NOT NULL,
    "sortOrder" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "submission__slug__unique_idx" ON "submission" USING btree ("slug");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "submission_analysis" (
    "id" bigserial PRIMARY KEY,
    "submissionId" bigint NOT NULL,
    "promptVersion" text NOT NULL,
    "summary" text NOT NULL,
    "technical" json NOT NULL,
    "demonstration" json NOT NULL,
    "idea" json NOT NULL,
    "gemmaUsage" json NOT NULL,
    "worthCloserReview" boolean NOT NULL,
    "whyWorthAttention" text NOT NULL,
    "whyNotSurfaced" text,
    "evidence" json NOT NULL,
    "highlights" json NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "submission_analysis_version_idx" ON "submission_analysis" USING btree ("submissionId", "promptVersion");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "submission_analysis"
    ADD CONSTRAINT "submission_analysis_fk_0"
    FOREIGN KEY("submissionId")
    REFERENCES "submission"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR finalist_brief
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('finalist_brief', '20260921194106756', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260921194106756', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
