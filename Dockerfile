FROM python:3.11-slim
WORKDIR /app
# Install dependencies
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Copy your code
COPY app/ .
# Keep the container running so you can execute scripts
CMD ["tail", "-f", "/dev/null"]