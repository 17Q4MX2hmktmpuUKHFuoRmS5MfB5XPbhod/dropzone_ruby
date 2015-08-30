Sham.config(Dropzone::Invoice) do |c|
  c.attributes do
   { expiration_in: 6, amount_due: 100_000_000, receiver_addr: TESTER_PUBLIC_KEY}
  end
end
