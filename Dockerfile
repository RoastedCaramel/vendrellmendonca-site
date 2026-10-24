FROM python:3.14-slim-trixie

# Use the same uv version as ci.yml
COPY --from=ghcr.io/astral-sh/uv:0.13.5 /uv /uvx /bin/

ENV \
    # stops Python from writing .pyc cache files
    PYTHONDONTWRITEBYTECODE=1 \
    # makes Python print output immediately instead of holding it in a buffer
    PYTHONUNBUFFERED=1 \
    # has uv precompile the packages bytecode once at build time
    UV_COMPILE_BYTECODE=1 \
    # makes uv copy files instead of hard-linking them from its cache
    UV_LINK_MODE=copy \
    # forbids uv from downloading its own Python
    UV_PYTHON_DOWNLOADS=never \
    # puts the project’s virtual environment first in the search path
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

COPY pyproject.toml uv.lock .python-version ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-install-project

COPY . .

RUN SECRET_KEY=build-only python manage.py collectstatic --noinput

RUN useradd --create-home app \
    && mkdir /app/data \
    && chown app /app/data
USER app

EXPOSE 8000

CMD ["sh", "-c", "python manage.py migrate --noinput && gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2"]
