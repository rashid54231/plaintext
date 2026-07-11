-- ============================================
-- TaskFlow App v2.0 - Supabase Migration
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================

-- 1. Create Users Table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('manager', 'student')),
  phone TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create Tasks Table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  assigned_date TIMESTAMPTZ DEFAULT now(),
  due_date TIMESTAMPTZ NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  completed_date TIMESTAMPTZ,
  assigned_to_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  assigned_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  submission_path TEXT,
  review_comment TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'inProgress', 'completed', 'overdue')),
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  category TEXT
);

-- 3. Task Assignments (Many-to-Many)
CREATE TABLE IF NOT EXISTS task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(task_id, user_id)
);

-- 4. Task Comments
CREATE TABLE IF NOT EXISTS task_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_role TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_by ON tasks(assigned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_task_assignments_task ON task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_user ON task_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_task ON task_comments(task_id);

-- 6. Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES - USERS
-- ============================================
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow signup" ON users;
CREATE POLICY "Allow signup" ON users FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (true);

-- ============================================
-- RLS POLICIES - TASKS
-- ============================================
DROP POLICY IF EXISTS "All can read tasks" ON tasks;
CREATE POLICY "All can read tasks" ON tasks FOR SELECT USING (true);

DROP POLICY IF EXISTS "All can insert tasks" ON tasks;
CREATE POLICY "All can insert tasks" ON tasks FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "All can update tasks" ON tasks;
CREATE POLICY "All can update tasks" ON tasks FOR UPDATE USING (true);

DROP POLICY IF EXISTS "All can delete tasks" ON tasks;
CREATE POLICY "All can delete tasks" ON tasks FOR DELETE USING (true);

-- ============================================
-- RLS POLICIES - TASK ASSIGNMENTS
-- ============================================
DROP POLICY IF EXISTS "All can read assignments" ON task_assignments;
CREATE POLICY "All can read assignments" ON task_assignments FOR SELECT USING (true);

DROP POLICY IF EXISTS "All can insert assignments" ON task_assignments;
CREATE POLICY "All can insert assignments" ON task_assignments FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "All can delete assignments" ON task_assignments;
CREATE POLICY "All can delete assignments" ON task_assignments FOR DELETE USING (true);

-- ============================================
-- RLS POLICIES - COMMENTS
-- ============================================
DROP POLICY IF EXISTS "All can read comments" ON task_comments;
CREATE POLICY "All can read comments" ON task_comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "All can insert comments" ON task_comments;
CREATE POLICY "All can insert comments" ON task_comments FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "All can delete comments" ON task_comments;
CREATE POLICY "All can delete comments" ON task_comments FOR DELETE USING (true);

-- ============================================
-- FUNCTION: Single Manager Enforcement
-- ============================================
CREATE OR REPLACE FUNCTION check_manager_exists()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'manager' THEN
    IF EXISTS (SELECT 1 FROM users WHERE role = 'manager') THEN
      RAISE EXCEPTION 'Only one manager can be registered';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_single_manager ON users;
CREATE TRIGGER enforce_single_manager
  BEFORE INSERT ON users
  FOR EACH ROW EXECUTE FUNCTION check_manager_exists();

-- ============================================
-- Storage: task-submissions bucket
-- Run separately if needed
-- ============================================
-- INSERT INTO storage.buckets (id, name, public) VALUES ('task-submissions', 'task-submissions', true);
