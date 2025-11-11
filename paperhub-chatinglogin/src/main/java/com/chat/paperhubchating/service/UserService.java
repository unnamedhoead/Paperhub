package com.chat.paperhubchating.service;

import com.chat.paperhubchating.pojo.User;
import com.chat.paperhubchating.repository.UserRepository;
import com.chat.paperhubchating.service.impl.IUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service      //Spring 的bean
public class UserService implements IUserService{

    @Autowired
    UserRepository userRepository;


    public boolean verifyEmail(String email) {
        Optional<User> userOptional = userRepository.findByEmail(email);
        if (userOptional.isPresent()) {
            User user = userOptional.get();
            user.setIsEmailVerified(true);
            userRepository.save(user);
            return true;
        } else {
            return false;
        }
    }
}
