require_relative 'invoice'

Sham.config(Dropzone::Payment) do |c|
  c.attributes do
   # Tester2 generates an invoice to Tester1
   invoice_id = Dropzone::Invoice.sham!(:build).save! TESTER2_PRIVATE_KEY

   # Tester 1 marks payment to Tester 2
   { description: 'abc', invoice_txid: invoice_id, 
     delivery_quality: 8, product_quality: 8, communications_quality: 8,
     receiver_addr: TESTER2_PUBLIC_KEY}
  end
end
