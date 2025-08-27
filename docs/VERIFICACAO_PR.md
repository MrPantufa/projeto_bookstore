# Guia de verificação (PR 20250827-003050)

- **Paginação DRF**: page_size=5, page_size_query_param=page_size.
- **Debug Toolbar**: app + middleware ativos; rota **/__debug__/**.
- **Poetry**: *lock* sincronizado com **pyproject.toml**.

## Como rodar localmente
1. python -m pip install --user pipx
2. pipx ensurepath  (feche e reabra o terminal se necessário)
3. pipx install poetry
4. poetry env use 3.12
5. poetry install --no-root
6. poetry run python manage.py migrate --no-input
7. poetry run pytest -q

Atualizado em 20250827-003242
