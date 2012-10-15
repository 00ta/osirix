//
//  OSIPathExtrusionROI.m
//  OsiriX_Lion
//
//  Created by Joël Spaltenstein on 10/4/12.
//  Copyright (c) 2012 OsiriX Team. All rights reserved.
//

#import "OSIPathExtrusionROI.h"
#import "OSIFloatVolumeData.h"
#import "OSIROIMask.h"

@interface OSIPathExtrusionROI ()
@property (nonatomic, readwrite, retain) N3BezierPath *path;
@property (nonatomic, readwrite, assign) OSISlab slab;
@property (nonatomic, readwrite, retain) NSString *name;
//- (NSData *)_maskRunsDataForSlab:(OSISlab)slab dicomToPixTransform:(N3AffineTransform)dicomToPixTransform minCorner:(N3VectorPointer)minCornerPtr;
@end


@implementation OSIPathExtrusionROI

@synthesize path = _path;
@synthesize slab = _slab;
@synthesize name = _name;

- (id)initWith:(N3BezierPath *)path slab:(OSISlab)slab homeFloatVolumeData:(OSIFloatVolumeData *)floatVolumeData name:(NSString *)name
{
	if ( (self = [super init]) ) {
        [self setHomeFloatVolumeData:floatVolumeData];
        self.path = path;
        self.slab = slab;
        self.name = name;
	}
	return self;
}

- (void)dealloc
{
    self.path = nil;
    self.name = nil;
    [_cachedMaskRunsData release];
    _cachedMaskRunsData = nil;
    
    [super dealloc];
}

- (NSArray *)convexHull
{
	NSMutableArray *convexHull;
	NSUInteger i;
	N3Vector control1;
	N3Vector control2;
	N3Vector endpoint;
	N3BezierPathElement elementType;
    N3Vector halfNormal = N3VectorScalarMultiply(self.slab.plane.normal, .5);
	
	convexHull = [NSMutableArray array];
	
	for (i = 0; i < [self.path elementCount]; i++) {
		elementType = [self.path elementAtIndex:i control1:&control1 control2:&control2 endpoint:&endpoint];
		switch (elementType) {
			case N3MoveToBezierPathElement:
			case N3LineToBezierPathElement:
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(endpoint, halfNormal)]];
				break;
			case N3CurveToBezierPathElement:
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(control1, halfNormal)]];
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(control2, halfNormal)]];
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(endpoint, halfNormal)]];
				break;
			default:
				break;
		}
	}
    
    halfNormal = N3VectorInvert(halfNormal);
	
    for (i = 0; i < [self.path elementCount]; i++) {
		elementType = [self.path elementAtIndex:i control1:&control1 control2:&control2 endpoint:&endpoint];
		switch (elementType) {
			case N3MoveToBezierPathElement:
			case N3LineToBezierPathElement:
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(endpoint, halfNormal)]];
				break;
			case N3CurveToBezierPathElement:
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(control1, halfNormal)]];
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(control2, halfNormal)]];
				[convexHull addObject:[NSValue valueWithN3Vector:N3VectorAdd(endpoint, halfNormal)]];
				break;
			default:
				break;
		}
	}

	return convexHull;
}

- (OSIROIMask *)ROIMaskForFloatVolumeData:(OSIFloatVolumeData *)floatVolume// BS Implementation, need to make this work everywhere!
{
	N3MutableBezierPath *volumeBezierPath;
	N3BezierPathElement segmentType;
	N3Vector endpoint;
	NSArray	*intersections;
	NSMutableArray *intersectionNumbers;
	NSMutableArray *ROIRuns;
	OSIROIMaskRun maskRun;
	CGFloat minY;
	CGFloat maxY;
	CGFloat z;
	BOOL zSet;
	NSValue *vectorValue;
	NSNumber *number;
	NSInteger i;
	NSInteger j;
	NSInteger runStart;
	NSInteger runEnd;
	
    // make sure floatVolume's z direction is perpendicular to the plane
    assert(N3VectorLength(N3VectorCrossProduct(N3VectorApplyTransformToDirectionalVector(self.slab.plane.normal, floatVolume.volumeTransform), N3VectorMake(0, 0, 1))) < 0.01);
    
	volumeBezierPath = [[self.path mutableCopy] autorelease];
    [volumeBezierPath applyAffineTransform:N3AffineTransformConcat(floatVolume.volumeTransform, N3AffineTransformMakeTranslation(0, -.5, 0))];
	[volumeBezierPath flatten:N3BezierDefaultFlatness];
	zSet = NO;
	ROIRuns = [NSMutableArray array];
	minY = CGFLOAT_MAX;
	maxY = -CGFLOAT_MAX;
    z = 0;
	
	for (i = 0; i < [volumeBezierPath elementCount]; i++) {
		[volumeBezierPath elementAtIndex:i control1:NULL control2:NULL endpoint:&endpoint];
#if CGFLOAT_IS_DOUBLE
		endpoint.z = round(endpoint.z);
#else
		endpoint.z = roundf(endpoint.z);
#endif
		[volumeBezierPath setVectorsForElementAtIndex:i control1:N3VectorZero control2:N3VectorZero endpoint:endpoint];
		minY = MIN(minY, endpoint.y);
		maxY = MAX(maxY, endpoint.y);
		
		if (zSet == NO) {
			z = endpoint.z;
			zSet = YES;
		}
		
		assert (endpoint.z == z);
	}
	
	minY = floor(minY);
	maxY = ceil(maxY);
    maskRun = OSIROIMaskRunZero;
	maskRun.depthIndex = z;
    
    if (z < 0 || z >= floatVolume.pixelsDeep) {
        return [[[OSIROIMask alloc] initWithMaskRuns:[NSArray array]] autorelease];
    }
	
	for (i = minY; i <= maxY; i++) {
        if (i < 0 || i >= floatVolume.pixelsHigh) {
            continue;
        }
        
		maskRun.heightIndex = i;
		intersections = [volumeBezierPath intersectionsWithPlane:N3PlaneMake(N3VectorMake(0, i, 0), N3VectorMake(0, 1, 0))];
		
		intersectionNumbers = [NSMutableArray array];
		for (vectorValue in intersections) {
			[intersectionNumbers addObject:[NSNumber numberWithDouble:[vectorValue N3VectorValue].x]];
		}
		[intersectionNumbers sortUsingSelector:@selector(compare:)];
		for(j = 0; j+1 < [intersectionNumbers count]; j++, j++) {
			runStart = round([[intersectionNumbers objectAtIndex:j] doubleValue]);
			runEnd = round([[intersectionNumbers objectAtIndex:j+1] doubleValue]);
            
            if (runStart == runEnd || runStart >= (NSInteger)floatVolume.pixelsWide || runEnd < 0) {
                continue;
            }
            
            runStart = MAX(runStart, 0);
            runEnd = MIN(runEnd, floatVolume.pixelsWide - 1);
            
			if (runEnd > runStart) {
				maskRun.widthRange = NSMakeRange(runStart, runEnd - runStart);
                OSIROIMaskRun maskRunCopy = maskRun;
                for (z = 0; z < floatVolume.pixelsDeep; z++) {
                    maskRunCopy.depthIndex = z;
                    [ROIRuns addObject:[NSValue valueWithOSIROIMaskRun:maskRunCopy]];
                }
			}
		}
	}
	
    return [[[OSIROIMask alloc] initWithMaskRuns:ROIRuns] autorelease];
}

@end
