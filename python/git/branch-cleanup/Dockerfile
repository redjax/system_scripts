FROM cgr.dev/chainguard/wolfi-base AS build

ARG python_version=3.12

WORKDIR /build

ARG python_version
RUN apk add --no-cache python-${python_version} py${python_version}-pip

RUN python -m venv /venv

COPY requirements.txt /requirements.txt
RUN /venv/bin/pip install --no-cache-dir -r /requirements.txt

FROM cgr.dev/chainguard/wolfi-base

ARG python_version=3.12

RUN apk add --no-cache python-${python_version}

WORKDIR /app

COPY --from=build /venv /venv

COPY clean_branches.py /app/

## Use non-root user
USER nobody

ENV PATH="/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["python", "/app/clean_branches.py"]
