package com.example.demo.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // อนุญาตให้ Flutter (ที่รันบน localhost หรือเครื่องอื่นๆ) เข้าถึงได้
        registry.addMapping("/api/v1/**")
                .allowedOrigins("*") // อนุญาตทุก Origin
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS");
    }
}