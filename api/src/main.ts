import fastifyHelmet from '@fastify/helmet';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { WsAdapter } from '@nestjs/platform-ws';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { WINSTON_MODULE_NEST_PROVIDER } from 'nest-winston';
import { cleanupOpenApiDoc, ZodValidationPipe } from 'nestjs-zod';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter(), {
    bufferLogs: true,
  });

  app.enableCors(); // Permet les requêtes cross-origin (CORS)

  app.register(fastifyHelmet, {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: [`'self'`],
        styleSrc: [`'self'`, `'unsafe-inline'`],
        imgSrc: [`'self'`, 'data:', 'validator.swagger.io'],
        scriptSrc: [`'self'`, `https: 'unsafe-inline'`],
      },
    },
  }); // Ajoute des en-têtes de sécurité HTTP

  app.setGlobalPrefix('api'); // Préfixe global pour toutes les routes (ex: /api/...)

  app.use(
    (_req: unknown, res: { setHeader: (arg0: string, arg1: string) => void }, next: () => void) => {
      res.setHeader('X-Powered-By', 'Salv Skate Co. API');
      next();
    },
  ); // Personnalise l'en-tête X-Powered-By pour masquer la technologie utilisée

  app.useGlobalPipes(new ZodValidationPipe()); // Utilise Zod pour la validation des données d'entrée
  app.useWebSocketAdapter(new WsAdapter(app));

  app.enableShutdownHooks(); // Permet de gérer les hooks de shutdown pour une fermeture propre de l'application

  app.useLogger(app.get(WINSTON_MODULE_NEST_PROVIDER)); // Utilise Winston comme logger global pour NestJS

  const config = new DocumentBuilder()
    .setTitle('Documentation Escape the Horde')
    .setDescription('API REST pour le jeu Escape the Horde')
    .setVersion('1.0')
    .build();
  const documentFactory = () => SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, cleanupOpenApiDoc(documentFactory()));
  // La documentation Swagger sera accessible à l'URL http://localhost:3000/api/docs

  await app.listen(process.env.PORT || 3000, '0.0.0.0');
}
bootstrap();
