package com.example.paperhub.common.security;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.common.exception.ForbiddenException;

public final class PermissionUtils {
    private PermissionUtils() {
    }

    public static void ensureAdmin(User user) {
        if (user == null || (user.getRole() != UserRole.ADMIN && user.getRole() != UserRole.SUPER_ADMIN)) {
            throw new ForbiddenException("需要管理员权限");
        }
    }

    public static void ensureSuperAdmin(User user) {
        if (user == null || user.getRole() != UserRole.SUPER_ADMIN) {
            throw new ForbiddenException("需要超级管理员权限");
        }
    }
}
