Sham.config(Dropzone::Item) do |c|
  c.attributes do
    { description: "Item Description", price_currency: 'BTC',
      price_in_units: 100_000_000, expiration_in: 6, 
      latitude: 51.500782, longitude: -0.124669, radius: 1000 }
  end
end

