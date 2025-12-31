package com.devsecops;

import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;

@EnableWebSecurity
public class WebSecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable() // Kept as per your previous code
            .authorizeRequests()
                .anyRequest().permitAll() // Allow access to your increment API
            .and()
            .headers()
                // 1. Fixes: X-Content-Type-Options (ZAP 10021)
                .contentTypeOptions()
                .and()
                // 2. Fixes: Non-Storable/Cacheable Content (ZAP 10049)
                .cacheControl()
                .and()
                // 3. Fixes: Spectre Site Isolation (ZAP 90004)
                // Adds: Cross-Origin-Resource-Policy: same-origin
                .contentSecurityPolicy("script-src 'self'; object-src 'self'; report-uri /csp-report-endpoint/")
                .and()
                .addHeaderWriter(new org.springframework.security.web.header.writers.StaticHeadersWriter("Cross-Origin-Resource-Policy", "same-origin"))
                .addHeaderWriter(new org.springframework.security.web.header.writers.StaticHeadersWriter("Cross-Origin-Embedder-Policy", "require-corp"))
                .addHeaderWriter(new org.springframework.security.web.header.writers.StaticHeadersWriter("Cross-Origin-Opener-Policy", "same-origin"));
    }
}
