package com.chat.paperhubchating.service.impl;

public interface IUserService {
    /**
     *  验证邮箱是否存在并设置邮箱已验证
     * @param email 邮箱地址
     * @return  如果存在并设置成功返回 true，否则返回 false
     */
    boolean verifyEmail(String email);
}
