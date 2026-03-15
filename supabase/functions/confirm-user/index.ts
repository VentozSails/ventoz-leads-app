import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function jsonResponse(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const { action, email, password } = await req.json()

    if (!email) return jsonResponse({ error: 'email is required' }, 400)

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Server-side invite verification: email must exist in ventoz_users or invited_users
    const normalizedEmail = email.toLowerCase().trim()
    const { data: userRow } = await adminClient
      .from('ventoz_users')
      .select('id, status')
      .eq('email', normalizedEmail)
      .maybeSingle()

    let isInvited = !!userRow

    if (!isInvited) {
      const { data: settings } = await adminClient
        .from('app_settings')
        .select('value')
        .eq('key', 'invited_users')
        .maybeSingle()
      if (settings?.value?.users) {
        isInvited = (settings.value.users as Array<{ email?: string }>).some(
          (u: { email?: string }) => u.email?.toLowerCase() === normalizedEmail
        )
      }
    }

    if (!isInvited) return jsonResponse({ error: 'Email is not invited' }, 403)

    // Action: "create" — create a pre-confirmed auth user (no confirmation email)
    if (action === 'create') {
      if (!password) return jsonResponse({ error: 'password is required' }, 400)

      const { data, error } = await adminClient.auth.admin.createUser({
        email: email.toLowerCase(),
        password,
        email_confirm: true,
      })

      if (error) {
        return jsonResponse({ error: error.message }, 400)
      }

      return jsonResponse({ ok: true, user_id: data.user?.id })
    }

    // Default action: confirm an existing user's email via SQL
    const { error: rpcError } = await adminClient.rpc('confirm_user_email', {
      target_email: email.toLowerCase(),
    })

    if (rpcError) {
      return jsonResponse({ error: rpcError.message }, 500)
    }

    return jsonResponse({ ok: true, confirmed: true })
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500)
  }
})
