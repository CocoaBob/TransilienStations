//
//  ViewController.m
//  TransilienStations
//
//  Created by CocoaBob on 14/07/15.
//  Copyright (c) 2015 CocoaBob. All rights reserved.
//

#import "MapViewController.h"

@interface Station : NSObject

@property (nonatomic, assign) NSUInteger index;
@property (nonatomic, strong) NSString *code;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) float latitude;
@property (nonatomic, assign) float longitude;

@end

@implementation Station

@end

@import CHCSVParser;

@interface MapViewController () <CHCSVParserDelegate, MKMapViewDelegate>

@property (nonatomic, weak) IBOutlet MKMapView *mapView;

@property (nonatomic, assign) CGFloat latMin;
@property (nonatomic, assign) CGFloat latMax;
@property (nonatomic, assign) CGFloat latCnt;
@property (nonatomic, assign) CGFloat latSlcSize;

@property (nonatomic, assign) CGFloat lngMin;
@property (nonatomic, assign) CGFloat lngMax;
@property (nonatomic, assign) CGFloat lngCnt;
@property (nonatomic, assign) CGFloat lngSlcSize;

@property (nonatomic, assign) CGFloat maxSlc;
@property (nonatomic, assign) CGFloat slcCnt;

@end

@implementation MapViewController {
    NSMutableArray *_stations;
    NSMutableDictionary *_slices;
    Station *_currentStation;
    BOOL _isInitialised;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // KVO
    [self addObserver:self forKeyPath:@"latMin" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"latMax" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"latCnt" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"lngMin" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"lngMax" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"lngCnt" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"maxSlc" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"slcCnt" options:0 context:NULL];

    // Parse data
    CHCSVParser *parser = [[CHCSVParser alloc] initWithContentsOfCSVURL:[[NSBundle mainBundle] URLForResource:@"AllStationsOrderByCode" withExtension:@"csv"]];
    parser.delegate = self;
    [parser parse];
    parser = nil;
    
    // Show map annotations
    [self addStationAnnotations];
    
    // Update slices
    CGFloat latMin = FLT_MAX;
    CGFloat latMax = FLT_MIN;
    CGFloat lngMin = FLT_MAX;
    CGFloat lngMax = FLT_MIN;
    for (Station *station in _stations) {
        latMin = MIN(latMin, station.latitude);
        latMax = MAX(latMax, station.latitude);
        lngMin = MIN(lngMin, station.longitude);
        lngMax = MAX(lngMax, station.longitude);
    }
    self.latMin = 47.998;//latMin;
    self.latMax = 49.295;//latMax;
    self.latCnt = 200;
    self.lngMin = 1.355;//lngMin;
    self.lngMax = 3.425;//lngMax;
    self.lngCnt = 200;
    
    // Make slices
    [self updateSlices];
    
    // Update UI
    [self updateOverlays];
    
    // Show map rect
    MKMapPoint point1 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(_latMax, _lngMin));
    MKMapPoint point2 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(_latMin, _lngMax));
    MKMapRect mapRect = MKMapRectMake(point1.x, point1.y, ABS(point2.x - point1.x), ABS(point2.y - point1.y));
    [_mapView setVisibleMapRect:mapRect animated:YES];
    
    _isInitialised = YES;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"latMin"];
    [self removeObserver:self forKeyPath:@"latMax"];
    [self removeObserver:self forKeyPath:@"latCnt"];
    [self removeObserver:self forKeyPath:@"lngMin"];
    [self removeObserver:self forKeyPath:@"lngMax"];
    [self removeObserver:self forKeyPath:@"lngCnt"];
    [self removeObserver:self forKeyPath:@"maxSlc"];
    [self removeObserver:self forKeyPath:@"slcCnt"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (_isInitialised) {
        if (![@"maxSlc" isEqualToString:keyPath] &&
            ![@"slcCnt" isEqualToString:keyPath]) {
            [self updateSlices];
            [self updateOverlays];
        }
    }
}

#pragma mark - CHCSVParserDelegate


- (void)parserDidBeginDocument:(CHCSVParser *)parser {
    _stations = [NSMutableArray new];
}

- (void)parser:(CHCSVParser *)parser didBeginLine:(NSUInteger)recordNumber {
    _currentStation = [Station new];
    _currentStation.index = recordNumber;
}

- (void)parser:(CHCSVParser *)parser didReadField:(NSString *)field atIndex:(NSInteger)fieldIndex {
    switch (fieldIndex) {
        case 0:
            _currentStation.code = field;
            break;
        case 1:
            _currentStation.name = field;
            break;
        case 2:
            _currentStation.latitude = [field floatValue];
            break;
        case 3:
            _currentStation.longitude = [field floatValue];
            break;
        default:
            break;
    }
}

- (void)parser:(CHCSVParser *)parser didEndLine:(NSUInteger)recordNumber {
    [_stations addObject:_currentStation];
}

#pragma mark - MKMapViewDelegate

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
        renderer.strokeColor = [NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:0.5];
        renderer.lineWidth = 1;
        return renderer;
    } else if ([overlay isKindOfClass:[MKPolygon class]]) {
        MKPolygonRenderer *renderer = [[MKPolygonRenderer alloc] initWithOverlay:overlay];
        renderer.fillColor = [NSColor colorWithDeviceRed:0 green:1 blue:0 alpha:0.5];
        renderer.lineWidth = 1;
        return renderer;
    }
    return nil;
}

#pragma mark -

- (void)addStationAnnotations {
    NSMutableArray *annotations = [NSMutableArray new];
    for (Station *station in _stations) {
        MKPointAnnotation *annotation = [MKPointAnnotation new];
        [annotations addObject:annotation];
        annotation.coordinate = CLLocationCoordinate2DMake(station.latitude, station.longitude);
        annotation.title = station.name;
        annotation.subtitle = station.code;
        [self.mapView addAnnotation:annotation];
    }
}

#pragma mark - Slices

- (void)updateSlices {
    self.latSlcSize = (_latMax - _latMin) / _latCnt;
    self.lngSlcSize = (_lngMax - _lngMin) / _lngCnt;
    
    CLLocationDistance sliceDistanceLat = [[[CLLocation alloc] initWithLatitude:_latMin longitude:_lngMin] distanceFromLocation:
                                           [[CLLocation alloc] initWithLatitude:_latMin + _latSlcSize longitude:_lngMin]];
    CLLocationDistance sliceDistanceLng = [[[CLLocation alloc] initWithLatitude:_latMin longitude:_lngMin] distanceFromLocation:
                                           [[CLLocation alloc] initWithLatitude:_latMin longitude:_lngMin + _lngSlcSize]];
    
    NSLog(@"Slice distance: Lat = %.2f meters, Lng = %.2f meters",sliceDistanceLat,sliceDistanceLng);
    
    _slices = [NSMutableDictionary new];
    for (Station *station in _stations) {
        size_t x = (size_t)floorf((station.longitude - _lngMin) / _lngSlcSize);
        size_t y = (size_t)floorf((station.latitude - _latMin) / _latSlcSize);
        NSString *key = [NSString stringWithFormat:@"%02zu%02zu",y,x]; // LatLng
        NSMutableArray *sliceStations = [_slices[key] mutableCopy];
        if (!sliceStations) {
            sliceStations = [NSMutableArray new];
        }
        [sliceStations addObject:station];
        [_slices setObject:sliceStations forKey:key];
    }
    self.slcCnt = _slices.count;
    
    size_t largestSliceStationCount = FLT_MIN;
    for (NSArray *stations in [_slices allValues]) {
        largestSliceStationCount = MAX(largestSliceStationCount, stations.count);
    }
    self.maxSlc = largestSliceStationCount;
    
    // Check if all stations are in the list
    NSUInteger stationsCount = 0;
    for (NSArray *stations in [_slices allValues]) {
        stationsCount += stations.count;
    }
}

- (void)updateOverlays {
    [_mapView removeOverlays:[_mapView overlays]];
    
    for (int x = 0; x <= _lngCnt; ++x) {
        CLLocationCoordinate2D coordinates[2] = {CLLocationCoordinate2DMake(_latMin, _lngMin + _lngSlcSize * x),CLLocationCoordinate2DMake(_latMax, _lngMin + _lngSlcSize * x)};
        MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coordinates count:2];
        [_mapView addOverlay:polyline level:MKOverlayLevelAboveRoads];
    }
    for (int y = 0; y <= _latCnt; ++y) {
        CLLocationCoordinate2D coordinates[2] = {CLLocationCoordinate2DMake(_latMin + _latSlcSize * y, _lngMin),CLLocationCoordinate2DMake(_latMin + _latSlcSize * y, _lngMax)};
        MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coordinates count:2];
        [_mapView addOverlay:polyline level:MKOverlayLevelAboveRoads];
    }
    
    [self highlightLargestSlices];
}

- (void)highlightLargestSlices {
    NSArray *sortedSlices = [[_slices allValues] sortedArrayUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
        if (obj1.count < obj2.count) {
            return NSOrderedAscending;
        } else if (obj1.count > obj2.count) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    NSUInteger count = MIN(sortedSlices.count, 10);
    for (NSUInteger i = sortedSlices.count - 1; i >= sortedSlices.count - count; --i) {
        NSArray *stations = sortedSlices[i];
        Station *station = [stations lastObject];
        size_t x = (size_t)floorf((station.longitude - _lngMin) / _lngSlcSize);
        size_t y = (size_t)floorf((station.latitude - _latMin) / _latSlcSize);
        
        CLLocationCoordinate2D coordinates[4] = {
            CLLocationCoordinate2DMake(_latMin + _latSlcSize * y, _lngMin + _lngSlcSize * x),
            CLLocationCoordinate2DMake(_latMin + _latSlcSize * (y + 1), _lngMin + _lngSlcSize * x),
            CLLocationCoordinate2DMake(_latMin + _latSlcSize * (y + 1), _lngMin + _lngSlcSize * (x + 1)),
            CLLocationCoordinate2DMake(_latMin + _latSlcSize * y, _lngMin + _lngSlcSize * (x + 1))};
        MKPolygon *polygon = [MKPolygon polygonWithCoordinates:coordinates count:4];
        [_mapView addOverlay:polygon];
    }
}

#pragma mark - Export

- (void)exportData:(NSData *)data {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"bin"];
    savePanel.canCreateDirectories = YES;
    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [data writeToURL:[savePanel URL] atomically:YES];
        }
    }];
}

- (IBAction)exportCodes:(id)sender {
    [self exportData:nil];
}

- (IBAction)exportNames:(id)sender {
    [self exportData:nil];
}

- (IBAction)exportLatLng:(id)sender {
    [self exportData:nil];
}

@end
