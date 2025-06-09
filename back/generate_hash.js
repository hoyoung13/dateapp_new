// generate_hash.js
const bcrypt = require('bcrypt');

(async () => {
  // 1) 여기 '원하는관리자비밀번호' 부분에 관리자 비밀번호(평문)를 적습니다.
  const plainPassword = '원하는관리자비밀번호';

  // 2) saltRounds는 보통 8~12 정도를 씁니다. (숫자가 높을수록 해시 연산이 조금 더 오래 걸리지만 보안성이 높아집니다.)
  const saltRounds = 10;

  try {
    const hash = await bcrypt.hash(plainPassword, saltRounds);
    console.log('bcrypt hash:', hash);
  } catch (err) {
    console.error('해시 생성 중 오류:', err);
  }
})();
