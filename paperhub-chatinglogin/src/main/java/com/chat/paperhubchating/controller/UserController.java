package com.chat.paperhubchating.controller;

import com.chat.paperhubchating.pojo.dto.ResponseMessage;
import com.chat.paperhubchating.service.impl.IUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/user")
public class UserController {

    @Autowired
    IUserService userService;

    @GetMapping("/verify")
    public ResponseMessage<String> verifyEmail(@RequestParam String email) {
        boolean verified = userService.verifyEmail(email);
        if (verified) {
            return ResponseMessage.success("邮箱验证成功", email);
        } else {
            return ResponseMessage.error("邮箱不存在", null);
        }
    }
}
