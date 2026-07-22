# Evidence 저장 규칙

실제 구현 저장소에서 각 Phase와 테스트의 검증 증거를 보관한다.

```text
evidence/
├─ phase-00/
├─ phase-01/
├─ ...
├─ phase-10/
└─ test/
   └─ T-XXXX/
```

포함할 것:

- 명령, 실행 시각, commit SHA, exit code
- test/build report와 artifact checksum
- device/OS/browser/store environment
- redacted screenshot/video
- migration/contract version
- 수동 설정 owner/완료일
- known issue/risk acceptance

포함하지 않을 것:

- secret, JWT, raw invite token, purchase receipt
- 실제 가족 이름·이메일·일정·집안일 제목
- 불필요한 production database dump
