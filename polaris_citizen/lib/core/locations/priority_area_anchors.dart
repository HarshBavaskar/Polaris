class AreaAnchor {
  final String city;
  final String area;
  final String pincode;
  final double lat;
  final double lng;

  const AreaAnchor({
    required this.city,
    required this.area,
    required this.pincode,
    required this.lat,
    required this.lng,
  });
}

const List<AreaAnchor> priorityAreaAnchors = <AreaAnchor>[
  AreaAnchor(
    city: 'Mumbai',
    area: 'Andheri',
    pincode: '400053',
    lat: 19.1197,
    lng: 72.8468,
  ),
  AreaAnchor(
    city: 'Mumbai',
    area: 'Bandra',
    pincode: '400050',
    lat: 19.0596,
    lng: 72.8295,
  ),
  AreaAnchor(
    city: 'Mumbai',
    area: 'Dadar',
    pincode: '400014',
    lat: 19.0178,
    lng: 72.8478,
  ),
  AreaAnchor(
    city: 'Thane',
    area: 'Thane West',
    pincode: '400601',
    lat: 19.2183,
    lng: 72.9781,
  ),
  AreaAnchor(
    city: 'Thane',
    area: 'Mumbra',
    pincode: '400612',
    lat: 19.1881,
    lng: 73.0245,
  ),
  AreaAnchor(
    city: 'Navi Mumbai',
    area: 'Vashi',
    pincode: '400703',
    lat: 19.0760,
    lng: 72.9986,
  ),
  AreaAnchor(
    city: 'Navi Mumbai',
    area: 'Belapur',
    pincode: '400614',
    lat: 19.0330,
    lng: 73.0297,
  ),
  AreaAnchor(
    city: 'Palghar',
    area: 'Vasai',
    pincode: '401202',
    lat: 19.4912,
    lng: 72.8054,
  ),
  AreaAnchor(
    city: 'Palghar',
    area: 'Boisar',
    pincode: '401501',
    lat: 19.8045,
    lng: 72.7559,
  ),
];
