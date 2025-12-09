# Department Documents Implementation

## Overview
Added document upload functionality to departments, allowing users to upload up to 3 optional documents per department.

## Database Changes

### SQL Migration (`ADD_DEPARTMENT_DOCUMENTS.sql`)
Run this SQL script in Supabase SQL Editor to add document columns:

```sql
ALTER TABLE departments 
ADD COLUMN IF NOT EXISTS document_1_url TEXT,
ADD COLUMN IF NOT EXISTS document_1_name TEXT,
ADD COLUMN IF NOT EXISTS document_2_url TEXT,
ADD COLUMN IF NOT EXISTS document_2_name TEXT,
ADD COLUMN IF NOT EXISTS document_3_url TEXT,
ADD COLUMN IF NOT EXISTS document_3_name TEXT;
```

**Columns Added:**
- `document_1_url` - URL/path to first document
- `document_1_name` - Original filename of first document
- `document_2_url` - URL/path to second document
- `document_2_name` - Original filename of second document
- `document_3_url` - URL/path to third document
- `document_3_name` - Original filename of third document

All columns are optional (nullable).

## Supabase Storage Setup

### Create Storage Bucket
1. Go to Supabase Dashboard → Storage
2. Create a new bucket named: `department-documents`
3. Set bucket to **Public** (or configure RLS policies as needed)
4. Configure bucket policies for upload/read/delete access

### Storage Policies (Recommended)
```sql
-- Allow authenticated users to upload files
CREATE POLICY "Users can upload department documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'department-documents');

-- Allow authenticated users to read files
CREATE POLICY "Users can read department documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'department-documents');

-- Allow users to delete their own files
CREATE POLICY "Users can delete department documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'department-documents');
```

## New Dependencies

Added to `pubspec.yaml`:
- `file_picker: ^8.1.4` - For selecting files from device
- `url_launcher: ^6.3.1` - For opening/viewing documents

## New Service

### StorageService (`lib/services/storage_service.dart`)
- `uploadFile()` - Uploads file to Supabase Storage, returns public URL
- `deleteFile()` - Deletes a file from storage
- `deleteFiles()` - Deletes multiple files

**Features:**
- Generates unique filenames to avoid conflicts
- Organizes files in folders: `departments/{departmentId}/`
- Handles file upload errors gracefully

## UI Updates

### 1. Add Department Page (`lib/screens/departments/add_department_page.dart`)
**New Features:**
- ✅ 3 document upload fields (optional)
- ✅ File picker integration
- ✅ Display selected file names
- ✅ Remove document option
- ✅ Uploads documents after department creation
- ✅ Shows upload status

**UI Elements:**
- Document picker cards with upload button
- File name display when selected
- Remove button for selected files

### 2. Edit Department Page (`lib/screens/departments/edit_department_page.dart`)
**New Features:**
- ✅ Display existing documents
- ✅ View existing documents (opens in browser/app)
- ✅ Upload new documents (replaces existing)
- ✅ Remove documents (marks for deletion)
- ✅ Handles document replacement

**UI Elements:**
- Shows existing document names
- "View" button for existing documents
- Upload button for new/replacement documents
- Remove button for both existing and new documents

### 3. Department Detail Page (`lib/screens/departments/department_detail_page.dart`)
**New Features:**
- ✅ Documents section in Overview tab
- ✅ List of all uploaded documents
- ✅ Open/view documents (launches in external app)
- ✅ Only shows if documents exist

**UI Elements:**
- Documents card in Overview tab
- List of documents with file icons
- "Open" button to view documents

## File Upload Flow

1. **User selects file:**
   - Taps "Upload" button
   - File picker opens
   - User selects file
   - File name displayed

2. **On Save (Add Department):**
   - Department created first
   - Documents uploaded to `departments/{departmentId}/` folder
   - Document URLs stored in database

3. **On Save (Edit Department):**
   - If new file selected: old file deleted, new file uploaded
   - If document removed: old file deleted, URL set to null
   - Department updated with new document URLs

4. **Viewing Documents:**
   - User taps document in detail page
   - Document opens in external app/browser
   - Uses `url_launcher` package

## File Storage Structure

```
Supabase Storage Bucket: department-documents
├── departments/
│   ├── {department-id-1}/
│   │   ├── document1_1234567890.pdf
│   │   ├── document2_1234567891.docx
│   │   └── document3_1234567892.jpg
│   ├── {department-id-2}/
│   │   └── ...
```

## Error Handling

- File picker errors are caught and displayed
- Upload errors are logged but don't block department creation
- File deletion errors are logged but don't block updates
- Invalid URLs are handled gracefully

## Security Considerations

1. **Storage Bucket Access:**
   - Configure RLS policies for storage bucket
   - Restrict upload/delete to authenticated users
   - Consider role-based access (admin/leader only)

2. **File Validation:**
   - Consider adding file type restrictions
   - Consider adding file size limits
   - Consider virus scanning for uploads

3. **File Naming:**
   - Files are renamed with timestamps to avoid conflicts
   - Original filenames stored separately

## Future Enhancements

- [ ] File type validation (PDF, DOCX, etc.)
- [ ] File size limits
- [ ] Image preview for image files
- [ ] Download documents
- [ ] Document versioning
- [ ] Document categories/tags
- [ ] Bulk document operations
