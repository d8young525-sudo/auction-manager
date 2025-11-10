# Firebase 이메일 템플릿 한글화 설정

## 비밀번호 재설정 이메일 템플릿 변경 방법

### 1. Firebase Console 접속
https://console.firebase.google.com/

### 2. 프로젝트 선택
`auction-manager-52959` 프로젝트 선택

### 3. Authentication 설정
1. 좌측 메뉴에서 **Build** → **Authentication** 클릭
2. 상단 탭에서 **Templates** 클릭
3. **Email templates** 섹션 찾기

### 4. 비밀번호 재설정 템플릿 수정
1. **Password reset** 템플릿 선택 (또는 "비밀번호 재설정")
2. **Edit template** 버튼 클릭

### 5. 한글 템플릿 적용

#### 이메일 제목 (Subject):
```
옥션매니저 비밀번호 재설정 링크입니다
```

#### 이메일 본문 (Body):
```html
<p>안녕하세요,</p>

<p>%DISPLAY_NAME% 계정의 비밀번호를 재설정하려면 아래 링크를 클릭하세요.</p>

<p><a href="%LINK%">비밀번호 재설정하기</a></p>

<p>또는 아래 링크를 복사하여 브라우저에 붙여넣으세요:</p>
<p>%LINK%</p>

<p>만약 비밀번호 재설정을 요청하지 않으셨다면 이 이메일을 무시하셔도 됩니다.</p>

<p>감사합니다,<br>
옥션매니저 팀</p>
```

### 6. 발신자 정보 설정

#### From name (발신자 이름):
```
옥션매니저
```

#### Reply-to email (회신 이메일):
```
noreply@auction-manager-52959.firebaseapp.com
```

### 7. 저장
**Save** 버튼 클릭하여 변경사항 저장

---

## 추가 템플릿 설정 (선택사항)

### 이메일 인증 템플릿
**Email address verification** 템플릿도 같은 방식으로 한글화 가능

#### 제목:
```
옥션매니저 이메일 인증
```

#### 본문:
```html
<p>안녕하세요,</p>

<p>옥션매니저 계정을 생성해주셔서 감사합니다!</p>

<p>이메일 인증을 완료하려면 아래 링크를 클릭하세요:</p>

<p><a href="%LINK%">이메일 인증하기</a></p>

<p>감사합니다,<br>
옥션매니저 팀</p>
```

---

## 테스트

1. 앱에서 "비밀번호를 잊으셨나요?" 클릭
2. 이메일 주소 입력 후 전송
3. 이메일 확인 → 한글 템플릿으로 수신되는지 확인

---

## 주의사항

- Firebase는 기본적으로 영어 템플릿을 제공합니다
- 템플릿 변경 후 즉시 적용됩니다 (캐시 없음)
- `%LINK%`, `%DISPLAY_NAME%` 등의 변수는 반드시 유지해야 합니다
- HTML 태그 사용 가능 (스타일링 가능)

---

## 고급 설정: 커스텀 도메인

Firebase 기본 도메인 대신 자신의 도메인을 사용하려면:
1. Firebase Console → **Authentication** → **Settings**
2. **Authorized domains** 섹션에서 도메인 추가
3. DNS 설정 필요

---

이 설정을 완료하면 사용자가 한글로 된 이메일을 받게 됩니다!
