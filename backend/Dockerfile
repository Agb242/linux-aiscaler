# Étape 1 : Image de base
FROM node:18

# Répertoire de travail
WORKDIR /app

# Copier les fichiers nécessaires
COPY package.json .
COPY package-lock.json .
RUN npm install
COPY . .

# Exposer le port utilisé par l'application
EXPOSE 8080

# Lancer l'application
CMD ["npm", "start"]
