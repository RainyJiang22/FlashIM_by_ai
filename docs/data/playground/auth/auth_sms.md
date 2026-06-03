# POST /auth/sms 测试记录

## 接口信息

- 方法：`POST`
- 路径：`/auth/sms`
- 完整地址：`http://127.0.0.1:9600/auth/sms`
- 用途：发送模拟短信验证码，并直接返回 6 位随机数

## 请求体

```json
{
  "phone": "13800138000"
}
```

## curl 模板

```bash
curl -s -X POST http://127.0.0.1:9600/auth/sms \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000"}'
```

## 本次实际验证

- 验证时间：`2026-06-03`
- 测试目标：确认接口能返回手机号对应的 6 位随机验证码

### 实际执行命令

```bash
curl -s -X POST http://127.0.0.1:9600/auth/sms \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000"}'
```

### 实际返回结果

```json
{"phone":"13800138000","code":"526047"}
```

## 结果判断

- 接口返回成功
- 返回值中包含 `phone`
- 返回值中包含 6 位验证码 `code`
- 该验证码可作为后续 `/auth/login` 的测试输入

## 本接口结论

`POST /auth/sms` 工作正常，符合 playground 阶段“模拟发送验证码并直接返回验证码”的预期。
