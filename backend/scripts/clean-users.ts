/**
 * clean-users.ts
 *
 * Deletes ALL users and their related data (tickets, orders, carts, payments)
 * for a clean demo environment.
 *
 * Deletion order (respects FK constraints):
 *   1. tickets (FK to order_items, users)
 *   2. payments (FK to orders)
 *   3. order_items (FK to orders)
 *   4. orders (FK to users)
 *   5. cart_items (FK to carts)
 *   6. carts (FK to users)
 *   7. users
 *
 * Run:  node --import tsx scripts/clean-users.ts
 */
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
dotenv.config();

const prisma = new PrismaClient();

async function main() {
  console.log('Cleaning all user-related data...\n');

  const userCount = await prisma.users.count();
  console.log(`Users to delete: ${userCount}`);

  // 1. Tickets
  const t = await prisma.tickets.deleteMany({});
  console.log(`  Deleted ${t.count} tickets`);

  // 2. Payments
  const p = await prisma.payments.deleteMany({});
  console.log(`  Deleted ${p.count} payments`);

  // 3. Order items
  const oi = await prisma.order_items.deleteMany({});
  console.log(`  Deleted ${oi.count} order_items`);

  // 4. Orders
  const o = await prisma.orders.deleteMany({});
  console.log(`  Deleted ${o.count} orders`);

  // 5. Cart items
  const ci = await prisma.cart_items.deleteMany({});
  console.log(`  Deleted ${ci.count} cart_items`);

  // 6. Carts
  const c = await prisma.carts.deleteMany({});
  console.log(`  Deleted ${c.count} carts`);

  // 7. Users
  const u = await prisma.users.deleteMany({});
  console.log(`  Deleted ${u.count} users`);

  console.log('\n✓ All users and related data cleaned.');
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  prisma.$disconnect();
  process.exit(1);
});
