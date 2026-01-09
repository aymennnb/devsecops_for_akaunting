FROM php:8.3-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev \
    libicu-dev libzip-dev zip unzip \
    && docker-php-ext-install \
        pdo_mysql mbstring gd bcmath intl zip \
    && a2enmod rewrite

RUN git config --global --add safe.directory /var/www/html

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application
COPY . /var/www/html/
WORKDIR /var/www/html

# 🔥 CORRECTIONS CRITIQUES POUR LARAVEL
# 1. Créer l'utilisateur www-data avec ID spécifique
RUN groupadd -g 1000 www && \
    useradd -u 1000 -ms /bin/bash -g www www-data

# 2. Définir les permissions AVANT composer install
RUN chown -R www-data:www /var/www/html

# 3. Installer les dépendances avec le bon utilisateur
USER www-data
RUN composer install --no-interaction --prefer-dist \
    && npm install \
    && cp .env.example .env \
    && php artisan key:generate

# 4. Revenir à root pour les dernières configurations
USER root

# 5. Définir les permissions FINALES pour Laravel
RUN chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache \
    && chown -R www-data:www \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache

# 6. S'assurer que les répertoires de stockage existent
RUN mkdir -p /var/www/html/storage/logs \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/framework/cache \
    && chown -R www-data:www /var/www/html/storage \
    && chmod -R 775 /var/www/html/storage

# 7. Vérifier les permissions
RUN echo "=== Vérification des permissions ===" && \
    ls -la /var/www/html/storage/ && \
    ls -la /var/www/html/bootstrap/

EXPOSE 80

# Démarrer Apache avec l'utilisateur non-root
USER www-data
CMD ["apache2-foreground"]
