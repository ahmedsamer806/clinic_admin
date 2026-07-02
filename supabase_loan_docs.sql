-- ══════════════════════════════════════════════════════════
--  Loan Request Documents Schema + Storage Setup
--  Run this in the Supabase SQL Editor
-- ══════════════════════════════════════════════════════════

-- 1. Add missing document URL columns (skip if already exist)
ALTER TABLE public.loan_requests
  ADD COLUMN IF NOT EXISTS nid_front_url      text,
  ADD COLUMN IF NOT EXISTS nid_back_url       text,
  ADD COLUMN IF NOT EXISTS medical_report_url text,
  ADD COLUMN IF NOT EXISTS additional_images  text[] DEFAULT '{}';

-- 2. Remove the duplicate claim_report_url (the real column is claim_report_photo_url)
ALTER TABLE public.loan_requests
  DROP COLUMN IF EXISTS claim_report_url;

-- 2. Create the storage bucket for loan documents (public read)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'loan-docs',
  'loan-docs',
  true,
  10485760, -- 10 MB max per file
  ARRAY['image/jpeg','image/png','image/webp','image/gif',
        'application/pdf','image/heic','image/heif']
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 3. Storage RLS: let authenticated admins read from loan-documents bucket
DROP POLICY IF EXISTS "loan_docs_admin_all" ON storage.objects;
DROP POLICY IF EXISTS "admin_read_all_storage" ON storage.objects;
DROP POLICY IF EXISTS "admin_read_loan_documents" ON storage.objects;

-- Allow authenticated users to read any file in loan-documents
CREATE POLICY "admin_read_loan_documents" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'loan-documents');

-- Also allow downloads (signed URL creation)
DROP POLICY IF EXISTS "admin_download_loan_documents" ON storage.objects;
CREATE POLICY "admin_download_loan_documents" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'loan-documents')
  WITH CHECK (bucket_id = 'loan-documents');

-- 4. Ensure loan_requests table permissions are still correct
GRANT SELECT, INSERT, UPDATE, DELETE ON public.loan_requests TO authenticated;
