# Secrets

Folder này được tạo sẵn trong image tại `/var/www/html/secrets`.

Không commit hoặc build secret thật vào image. Secret thật nên được mount vào folder này ở runtime, hoặc truyền qua biến môi trường / secret manager của server.

Ví dụ nội dung phù hợp để mount ở runtime:

- private keys
- service account JSON
- license files không được public
- token file của dịch vụ bên thứ ba
