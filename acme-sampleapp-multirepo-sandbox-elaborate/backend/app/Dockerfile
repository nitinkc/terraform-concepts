FROM python:3.12-alpine@sha256:b64631e04e4920160c50fbe8d8df828f7f35f06f425cb44aa09bca53e708a35a

WORKDIR /app
COPY --chown=1000:1000 app.py /app/app.py
USER 1000:1000
EXPOSE 8000
CMD ["python", "/app/app.py"]
