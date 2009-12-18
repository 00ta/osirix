/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

//Abstract class for generalized control of DICOM sending.

#import <Cocoa/Cocoa.h>

enum TransferSyntaxCodes
{
	SendExplicitLittleEndian = 0, 
	SendJPEG2000Lossless = 1, 
	SendJPEG2000Lossy10 = 2,  
	SendJPEG2000Lossy20 = 3, 
	SendJPEG2000Lossy50 = 4, 
	SendJPEGLossless = 5,  
	SendJPEGLossy9 = 6, 
	SendJPEGLossy8 = 7, 
	SendJPEGLossy7 = 8, 
	SendImplicitLittleEndian = 9, 
	SendRLE = 10, 
	SendExplicitBigEndian = 11, 
	SendBZip = 12
};


enum SendServerType { osirixServer, offisServer };

@class Wait;
@class DCMTKStoreSCU;

/** \brief Window Controller for DICOM Send */
@interface SendController : NSWindowController
{
	NSArray				*_files;
	NSString			*_numberFiles;
	NSInteger			_keyImageIndex;
	NSInteger			_serverIndex;
	NSInteger			_offisTS;
	Wait				*_waitSendWindow;
	BOOL				_readyForRelease;
	BOOL				_abort;
	BOOL				sendROIs;
	NSRecursiveLock		*_lock;
	DCMTKStoreSCU		*storeSCU;
	NSDictionary		*_destinationServer;
	
	IBOutlet NSPopUpButton	*newServerList;
	IBOutlet NSMatrix		*keyImageMatrix;
	IBOutlet NSTextField	*numberImagesTextField, *addressAndPort;
	IBOutlet NSPopUpButton	*syntaxListOffis;
	
	// TLS password
	IBOutlet NSWindow *TLSAskPasswordWindow;
	NSString *TLSAskPasswordValue, *TLSAskPasswordServerName;
}

@property (retain) NSString *TLSAskPasswordValue, *TLSAskPasswordServerName;

+ (void)sendFiles:(NSArray *)files;
+ (void)sendFiles:(NSArray *)files toNode: (NSDictionary*) node;
+ (int) sendControllerObjects;
- (id)initWithFiles:(NSArray *)files;
- (id)serverAtIndex:(int)index;
- (id)server;
- (NSString *)numberFiles;
- (void)setNumberFiles:(NSString *)numberFiles;
- (IBAction) endSelectServer:(id) sender;
- (int)keyImageIndex;
- (void)setKeyImageIndex:(int)index;
- (void)releaseSelfWhenDone:(id)sender;
- (void)listenForAbort:(id)handler;
- (void)abort;
- (void)closeSendPanel:(id)sender;
- (IBAction)selectServer: (id)sender;
- (void) sendToNode: (NSDictionary*) node;
- (void) updateDestinationPopup:(NSNotification*) note;


- (NSDictionary*)TLSAskPrivateKeyPasswordForServer:(NSDictionary*)server;
- (BOOL)TLSIsValidPrivateKeyPassword:(NSString*)password forServer:(NSDictionary*)server;
- (void)TLSSavePrivateKeyPassword:(NSString*)password forServer:(NSDictionary*)server;
- (NSString*)TLSSavedPrivateKeyPasswordForServer:(NSDictionary*)server;
- (IBAction)TLSAskPrivateKeyPasswordCancel:(id)sender;
- (IBAction)TLSAskPrivateKeyPasswordOK:(id)sender;

@end
