from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm
    list_display = ['email', 'display_name', 'gym', 'is_active', 'is_staff', 'date_joined']
    search_fields = ['email', 'display_name', 'username']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Perfil', {'fields': ('display_name', 'avatar', 'avatar_url', 'gym', 'fitness_level',
                               'workout_types', 'available_days', 'bio', 'age', 'facebook_id')}),
    )
