# Autenticação por Token (DRF)

- Autenticação padrão: TokenAuthentication
- Permissão padrão: IsAuthenticated
- Obter token: POST /api-token-auth/  { "username": "<user>", "password": "<pass>" }
- Usar token: Header `Authorization: Token <token>`
- Teste: GET /bookstore/v1/product/ com e sem header (401 vs 200)
