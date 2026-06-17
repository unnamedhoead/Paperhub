package com.example.paperhub.user;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.user.dto.PrivacySettingsResp;
import com.example.paperhub.user.dto.UpdatePrivacySettingsReq;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 用户隐私设置 API：查询/修改关注列表、粉丝列表、收藏的可见性。
 */
@RestController
@RequestMapping("/users")
@CrossOrigin(origins = "*")
public class UserPrivacyController {

    private final UserService userService;

    public UserPrivacyController(UserService userService) {
        this.userService = userService;
    }

    /**
     * 获取当前登录用户的隐私设置。
     */
    @GetMapping("/me/privacy")
    public ResponseEntity<PrivacySettingsResp> getMyPrivacySettings(
            @AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        User fresh = userService.refreshUser(currentUser.getId());
        return ResponseEntity.ok(new PrivacySettingsResp(
                fresh.isHideFollowing(),
                fresh.isHideFollowers(),
                fresh.isPublicFavorites()
        ));
    }

    /**
     * 更新当前登录用户的隐私设置。
     */
    @PutMapping("/me/privacy")
    public ResponseEntity<PrivacySettingsResp> updatePrivacy(
            @AuthenticationPrincipal User currentUser,
            @RequestBody UpdatePrivacySettingsReq req) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        PrivacySettingsResp resp = userService.updatePrivacy(currentUser, req);
        return ResponseEntity.ok(resp);
    }
}
