from django.contrib.auth import get_user_model
from authentik.rbac.models import Role, Permission

import os

User = get_user_model()

# Read username from environment variable for flexibility
admin_username = os.getenv("AUTHENTIK_ADMIN_USER", "admin")

try:
    admin = User.objects.get(username=admin_username)
except User.DoesNotExist:
    print(f"[ERROR] User '{admin_username}' not found.")
    exit(1)

# Get the permission for accessing admin interface
try:
    perm = Permission.objects.get(codename="access_admin_interface")
except Permission.DoesNotExist:
    print("[ERROR] Permission 'access_admin_interface' not found.")
    exit(1)

# Grant direct permission
admin.user_permissions.add(perm)

# Create or get the admin role
role, _ = Role.objects.get_or_create(name="Admin UI Access")
role.permission_set.add(perm)

# Optional: Bind user to role (if role bindings exist in Authentik)
# from authentik.rbac.models import RoleBinding
# RoleBinding.objects.get_or_create(user=admin, role=role)

admin.save()
print(f"[INIT] Admin UI access granted to '{admin_username}' user.")

