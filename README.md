# Vox2Vocal Worker

Redis/BullMQ 기반 비동기 작업 서버입니다.

## 역할

- Queue job consume
- 알림, 이메일, 배치, 외부 API 동기화 같은 비동기 작업 처리
- Kubernetes health check 제공

## 포트

- HTTP health: `3003`

## 실행

```bash
npm install
npm run start:dev
```
