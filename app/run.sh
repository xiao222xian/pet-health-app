#!/bin/bash
flutter run \
  --dart-define=SUPABASE_URL=https://srljyvqojhhwbgtdojkh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNybGp5dnFvamhod2JndGRvamtoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4NjA1MTUsImV4cCI6MjA5MDQzNjUxNX0.WqF_9rHWFhzQf84KyLB9qP3ZE6GkPXnKuQ3V3IUaZaE \
  --dart-define=API_BASE_URL=https://stellar-passion-production-56af.up.railway.app/api/v1 \
  "$@"
