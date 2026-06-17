# Backend environment variables

`application.properties` imports ignored local overrides from
`src/main/resources/application-local.properties`. For local development, put
secrets there using the real Spring property names:

```powershell
spring.datasource.password=<mysql-password>
jwt.secret=<at-least-32-byte-secret>
spring.mail.password=<mail-password>
huawei.obs.ak=<obs-access-key>
huawei.obs.sk=<obs-secret-key>
```

Optional overrides:

```powershell
$env:DB_URL='jdbc:mysql://1.95.209.72:3306/paperHub'
$env:DB_USERNAME='team'
$env:MAIL_USERNAME='paperhub@paperhub.icu'
$env:HUAWEI_OBS_ENDPOINT='obs.cn-north-4.myhuaweicloud.com'
$env:HUAWEI_OBS_BUCKET='paperhub'
$env:CORS_ALLOWED_ORIGINS='http://localhost:8090,http://127.0.0.1:8090'
```

Then run:

```powershell
cd Backend/paperhub
./mvnw spring-boot:run
```
