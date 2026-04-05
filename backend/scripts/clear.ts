import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
prisma.events.updateMany({ data: { contract_address: null } }).then(() => console.log('Cleared DB')).finally(() => prisma.$disconnect());
