import pathlib
import re

REQ = pathlib.Path("requirements.txt")
PYPROJ = pathlib.Path("pyproject.toml")
LOCK = pathlib.Path("poetry.lock")

def _read(p: pathlib.Path) -> str:
    assert p.exists(), f"Arquivo esperado não encontrado: {p}"
    return p.read_text(encoding="utf-8")

def test_requirements_pins_principais_presentes():
    txt = _read(REQ)
    assert re.search(r"(?mi)^\s*django\s*==\s*5\.2\.5", txt), "Falta django==5.2.5"
    assert re.search(r"(?mi)^\s*djangorestframework\s*==\s*3\.16\.1", txt), "Falta djangorestframework==3.16.1"
    ok_toolbar = bool(re.search(r"(?mi)^\s*django-debug-toolbar\s*==\s*4\.\d+", txt)) or \
                 bool(re.search(r"(?mi)^\s*django-debug-toolbar\s*>=\s*4\.4.*<\s*5\.0", txt))
    assert ok_toolbar, "Falta django-debug-toolbar ~4.4.x"
    assert re.search(r"(?mi)^\s*asgiref\s*==\s*3\.9\.1", txt), "Falta asgiref==3.9.1"
    assert re.search(r"(?mi)^\s*tzdata\s*==\s*\d{4}\.\d", txt), "Falta tzdata==YYYY.M (Windows)"

def test_poetry_lock_presente_e_coerente_com_pyproject():
    assert PYPROJ.exists(), "pyproject.toml ausente"
    assert LOCK.exists(), "poetry.lock ausente (rode 'poetry lock')"
    lock = _read(LOCK)
    assert re.search(r'(?m)^\s*name\s*=\s*"django"\s*$', lock) or "django" in lock.lower(), \
        "Pacote django não encontrado no poetry.lock"
    assert re.search(r'(?m)^\s*version\s*=\s*"5\.2\.5"\s*$', lock) or 'version = "5.2.5"' in lock, \
        "poetry.lock não está travado em django==5.2.5 (rode 'poetry lock')"
