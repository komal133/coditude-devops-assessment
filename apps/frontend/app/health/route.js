// Lightweight health endpoint for the ALB target group (/health).
export const dynamic = 'force-dynamic';

export async function GET() {
  return Response.json({ status: 'ok' });
}
