package com.chat.paperhubchating.exception;

import com.chat.paperhubchating.pojo.dto.ResponseMessage;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandlerAdvice {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandlerAdvice.class);


    @ExceptionHandler({Exception.class})    //什么异常的注解
    public ResponseMessage handerException(Exception e, HttpServletRequest request, HttpServletResponse response) {
        //记录日志
        log.error("统一异常", e);
        return new ResponseMessage(500, e.getMessage(), null);
    }

}
