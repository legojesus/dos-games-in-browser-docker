FROM nginx:alpine

# Copy nginx configuration and static pages
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /etc/nginx/html/
COPY player.html /etc/nginx/html/
COPY player-homm3.html /etc/nginx/html/

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
