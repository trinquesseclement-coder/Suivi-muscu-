/**
 * Votre salle. Les marques servent à reconnaître les machines dans le catalogue
 * (à corriger dans l'onglet Machines si une machine n'est pas la bonne marque).
 */
export const GYM = {
  name: 'KOMEX',
  address: '64B rue Sully, 21000 Dijon',
  hours: '7j/7, 5h–23h',
  access: 'Tram : Mazen-Sully · parking gratuit à proximité',
}

export function gymMapsUrl(): string {
  const q = encodeURIComponent(`${GYM.name}, ${GYM.address}`)
  const ios = /iPhone|iPad|Macintosh/.test(navigator.userAgent)
  return ios ? `https://maps.apple.com/?q=${q}` : `https://www.google.com/maps/search/?api=1&query=${q}`
}
