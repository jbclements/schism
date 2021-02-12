%Author: Joseph Zhang
%Generate ampl. and phases for elev, u,v from TPXO9 using linear interp directly
%from nc files.
%Requires inputs: (1) list of open bnd lon/lat (generated by gen_fg.f90 with 1st 2 lines removed 
%                     (to easily read into mlab), then broken into different segments in each file); 
%                     longitude in [-180,180) or [0,360]
%                 (2) *.nc (in this dir)
%                 (3) iflag: 1: generate elev only; 2: elev, u,v
%  Also need to first download TPXO files
%Outputs: ap.out.[1,2..] (for bctides.in; see below for freq order, which is different from FES)
%Note that TPXO use 0 for junk values (e.g. on land) so the outputs may not be accurate near 
%ocean-land interface
clear all; close all;

iflag=2;
%List of open bnd seg's that contain lon/lat of open bnd nodes
open_ll={'fg.bp.0','fg.bp.1','fg.bp.2'}; 

%Output freq's must be first X of original freq's in nc
const={'m2','s2','n2','k2','k1','o1','p1','q1'}; 
nfr_out=length(const);

for iseg=1:length(open_ll)
%------------------------------------------------------
disp(['doing segment # ' num2str(iseg)]);
open=load(open_ll{iseg}); %ID,lon,lat of open bnd nodes
npt=size(open,1);
lat2=open(:,3);
lon2=open(:,2); 
indx=find(lon2<0);
lon2(indx)=lon2(indx)+360;
clear indx;

%junk value in TPXO is 0
for ifl=1:2*iflag-1 %loop over elev, u,v
  disp(['doing ifl=' num2str(ifl)]);
  if(ifl==1)
    ncid = netcdf.open(['h_tpxo9.v1.nc'],'NC_NOWRITE');
    vid=netcdf.inqVarID(ncid,'lat_z'); %(ny,nx)
    lat = double(netcdf.getVar(ncid, vid)); %ascending order (-90,90)
    vid=netcdf.inqVarID(ncid,'lon_z');
    lon = double(netcdf.getVar(ncid, vid)); %ascending order (0,360]
  elseif(ifl==2 || ifl==3)
    ncid = netcdf.open(['u_tpxo9.v1.nc'],'NC_NOWRITE');
    if(ifl==2) 
      vid=netcdf.inqVarID(ncid,'lat_u'); %(ny,nx)
      lat = double(netcdf.getVar(ncid, vid)); %ascending order (-90,90)
      vid=netcdf.inqVarID(ncid,'lon_u');
      lon = double(netcdf.getVar(ncid, vid)); %ascending order (0,360]
    else
      vid=netcdf.inqVarID(ncid,'lat_v'); %(ny,nx)
      lat = double(netcdf.getVar(ncid, vid)); %ascending order (-90,90)
      vid=netcdf.inqVarID(ncid,'lon_v');
      lon = double(netcdf.getVar(ncid, vid)); %ascending order (0,360]
    end
  else
    error('Unknown iflag')
  end
  [ny nx]=size(lon);

  %Assume freq in same order btw h_ and u_
  if(ifl==1)
    vid=netcdf.inqVarID(ncid,'ha'); %(ny,nx,nfr)
  elseif(ifl==2)
    vid=netcdf.inqVarID(ncid,'ua'); %cm/s
  else
    vid=netcdf.inqVarID(ncid,'va'); 
  end
  %Junk values of 0 on land
  amp0=double(netcdf.getVar(ncid, vid)); %(ny,nx,nfr)
  if(ifl~=1); amp0=amp0/100; end; %to m/s
  nfr=size(amp0,3);
  if(nfr<nfr_out); error('nfr<nfr_out'); end;

  if(ifl==1)
    vid=netcdf.inqVarID(ncid,'hp');
  elseif(ifl==2)
    vid=netcdf.inqVarID(ncid,'up');
  else
    vid=netcdf.inqVarID(ncid,'vp');
  end
  pha0=double(netcdf.getVar(ncid, vid)); %degr GMT
  netcdf.close(ncid);

  if(ifl==1) %init
    amp_out=zeros(npt,nfr_out,2*iflag-1);
    pha_out=zeros(npt,nfr_out,2*iflag-1);
  end

  for jfr=1:nfr_out
    amp_out(:,jfr,ifl)=griddata(reshape(lon,nx*ny,1),reshape(lat,nx*ny,1), ...
      reshape(amp0(:,:,jfr),nx*ny,1),lon2,lat2);
    pha_out(:,jfr,ifl)=griddata(reshape(lon,nx*ny,1),reshape(lat,nx*ny,1), ...
      reshape(pha0(:,:,jfr),nx*ny,1),lon2,lat2); %,'nearest'); %avoid wrap around
  end %for jfr
end %for ifl

%Output
fid=fopen(['ap.out.' num2str(iseg)],'w');
for i=1:nfr_out
  fprintf(fid,'%s\n',const{i});
  fprintf(fid,'%f %f\n',[amp_out(:,i,1) pha_out(:,i,1)]');
end %for
  
if(iflag==2)
  for i=1:nfr_out
    fprintf(fid,'%s\n',const{i});
    fprintf(fid,'%f %f %f %f\n',[amp_out(:,i,2) pha_out(:,i,2) amp_out(:,i,3) pha_out(:,i,3)]');
  end %for
end
fclose(fid);

clear open lon* lat* amp* pha*;
%------------------------------------------------------
end %for iseg (open bnd segments
