alter function public.get_app_runtime_policy(text, text) volatile;

comment on function public.get_app_runtime_policy(text, text) is
  'Returns the exact content-free runtime policy to anon/authenticated clients; VOLATILE because evaluated_at uses wall-clock time.';
