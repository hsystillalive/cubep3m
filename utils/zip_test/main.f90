!! ifort main.f90 -fpp -mcmodel=medium  -O3 -DNEUTRINOS && time ./a.out
implicit none
integer, parameter :: density_buffer=1.2
integer, parameter :: max_np=(576**3 + 288**3)*density_buffer
integer, parameter :: mesh_scale=4, nc_dim=2, nf_dim=nc_dim*mesh_scale
real(4), parameter :: v_resolution=16384
real(4) :: xv(6,max_np)
real(4) :: vmax, vmax_local, v_r2i, sec1, sec2
integer(4) :: np_local, np_dm, np_nu, ll(max_np), hoc(0:nc_dim+1,0:nc_dim+1,0:nc_dim+1), ierr
integer(1) :: PID(max_np)
integer(1) :: input1=1

select case (input1)
case (1)
  np_local=(576**3 + 288**3)/100
  !np_local=256**3
  call random_number(xv(:,1:np_local))
  xv=xv*8
  PID(1:np_local:2)=1
  PID(2:np_local:2)=2
case(2)
  xv(:,1)=(/3,2,3,1,2,4/)
  xv(:,2)=(/5,2,3,1,2,4/)
  xv(:,3)=(/2,2,3,1,2,4/)
  xv(:,4)=(/1+1./64,1+2./64,1+3./64,1,2,4/)
  xv(:,5)=(/6,2,3,1,2,4/)
  xv(:,6)=(/4.01,4.02,7.9,1,2,4/)
  np_local=6
  PID(1:np_local)=1 ! dm
# ifdef NEUTRINOS
    PID(1:np_local-1)=2 ! nu
# endif
endselect

call cpu_time(sec1)
call link_list
!print*,'hoc=',hoc(1:nc_dim,1:nc_dim,1:nc_dim)
!print*,'ll=',ll(1:np_local*2)
call cpu_time(sec2)
print*,'link_list elapsed time (sec) =',sec2-sec1

call cpu_time(sec1)
call checkpoint_fast
call cpu_time(sec2)
print*,'checkpoint_fast elapsed time (sec) =',sec2-sec1

call cpu_time(sec1)
call particle_intitialize_fast
call cpu_time(sec2)
print*,'particle_intitialize_fast elapsed time (sec) =',sec2-sec1
PRINT*, 'MAIN: DONE'

contains

subroutine link_list
implicit none
integer(4) :: i,j,k,pp
hoc(:,:,:)=0
pp=1
do
  if (pp>np_local) exit
  i=floor(xv(1,pp)/mesh_scale)+1
  j=floor(xv(2,pp)/mesh_scale)+1
  k=floor(xv(3,pp)/mesh_scale)+1
  ll(pp)=hoc(i,j,k)
  hoc(i,j,k)=pp
  pp=pp+1
enddo
end subroutine link_list



subroutine checkpoint_fast
implicit none
integer(4) :: i,j,k,l, rhoc_dm_i4, rhoc_nu_i4

vmax=maxval(abs(xv(4:6,1:np_local)))
v_r2i = v_resolution/vmax

open(11,file='zip1.dat',status='replace',access='stream',buffered='yes')
open(12,file='zip2.dat',status='replace',access='stream',buffered='yes')
open(13,file='zip3.dat',status='replace',access='stream',buffered='yes')
np_dm = count(PID(1:np_local)==1)
write(11) np_dm, v_r2i
#ifdef NEUTRINOS
  open(21,file='zip1_nu.dat',status='replace',access='stream',buffered='yes')
  open(22,file='zip2_nu.dat',status='replace',access='stream',buffered='yes')
  open(23,file='zip3_nu.dat',status='replace',access='stream',buffered='yes')
  np_nu = count(PID(1:np_local)==2)
  write(21) np_nu, v_r2i
#endif
print*, "checkpoint np_dm, np_nu =", np_dm, np_nu
print*, "vmax =",vmax
print*, "v_r2i =",v_r2i

do k=1,nc_dim
do j=1,nc_dim
do i=1,nc_dim
  rhoc_dm_i4=0; rhoc_nu_i4=0
  l=hoc(i,j,k)
  do while(l>0)
#   ifdef NEUTRINOS
      if (PID(l)==1) then
        rhoc_dm_i4=rhoc_dm_i4+1 ! increment of density
        write(11) int( mod( xv(1:3,l)/mesh_scale, 1. ) * 256 ,kind=1) ! write x
        write(11) int( xv(4:6,l) * v_r2i ,kind=2) ! write v
      else ! nu
        rhoc_nu_i4=rhoc_nu_i4+1
        write(21) int( mod( xv(1:3,l)/mesh_scale, 1. ) * 256 ,kind=1)
        write(21) int( xv(4:6,l) * v_r2i ,kind=2)
      endif ! PID
#   else
      rhoc_dm_i4=rhoc_dm_i4+1
      write(11) int( mod( xv(1:3,l)/mesh_scale, 1. ) * 256 ,kind=1)
      write(11) int( xv(4:6,l) * v_r2i ,kind=2)
#   endif
    l=ll(l)
  enddo ! while

  if (rhoc_dm_i4<255) then
    write(12) int(rhoc_dm_i4,kind=1) ! write density in int1
  else
    write(12) int(255,kind=1)
    write(13) rhoc_dm_i4 ! [255,]
  endif
# ifdef NEUTRINOS
    if (rhoc_nu_i4<255) then
      write(22) int(rhoc_nu_i4,kind=1)
    else
      write(22) int(255,kind=1)
      write(23) rhoc_nu_i4
    endif
# endif
enddo
enddo
enddo

close(11);close(12);close(13)
#ifdef NEUTRINOS
  close(21);close(22);close(23)
#endif
end subroutine checkpoint_fast



subroutine particle_intitialize_fast
implicit none
integer(4) :: i,j,k,l, np_uzip
integer(1) :: xi1(4,3), rhoc_i1(4)
integer(4) :: xi4(3), rhoc_i4
integer(2) :: vi2(3)
equivalence(xi1,xi4)
equivalence(rhoc_i4,rhoc_i1)

np_local=0; np_dm=0; np_nu=0; np_uzip=0; xv=0
open(11,file='zip1.dat',status='old',access='stream',buffered='yes')
open(12,file='zip2.dat',status='old',access='stream',buffered='yes')
open(13,file='zip3.dat',status='old',access='stream',buffered='yes')
read(11) np_dm, v_r2i
np_local=np_dm
do k=1,nc_dim
do j=1,nc_dim
do i=1,nc_dim
  rhoc_i4=0; xi4=0 ! clean up, very imortant.
  read(12) rhoc_i1(1) ! get number of particles in the coarse grid
  !print*,'particle_intitialize_fast: rhoc_i1 =',rhoc_i1
  !print*,'particle_intitialize_fast: rhoc_i4 =',rhoc_i4
  if (rhoc_i4==255) read(13) rhoc_i4
  !print*,'particle_intitialize_fast: rhoc_i4 =',rhoc_i4
  do l=1,rhoc_i4
    np_uzip=np_uzip+1
    read(11) xi1(1,:), vi2
    xv(1:3,np_uzip) = mesh_scale * ( xi4/256. + (/i,j,k/) - 1 )
    xv(4:6,np_uzip) = vi2 / v_r2i
  enddo
enddo
enddo
enddo
close(11);close(12);close(13)

!print*,xv

#ifdef NEUTRINOS
  open(21,file='zip1_nu.dat',status='old',access='stream',buffered='yes')
  open(22,file='zip2_nu.dat',status='old',access='stream',buffered='yes')
  open(23,file='zip3_nu.dat',status='old',access='stream',buffered='yes')
  read(21) np_nu, v_r2i
  np_local=np_local+np_nu
  do k=1,nc_dim
  do j=1,nc_dim
  do i=1,nc_dim
  rhoc_i4=0; xi4=0
  read(22) rhoc_i1(1)
  !print*,'particle_intitialize_fast: rhoc_i1 =',rhoc_i1
  !print*,'particle_intitialize_fast: rhoc_i4 =',rhoc_i4
  if (rhoc_i4==255) read(23) rhoc_i4
  !print*,'particle_intitialize_fast: rhoc_i4 =',rhoc_i4
  do l=1,rhoc_i4
    np_uzip=np_uzip+1
    read(21) xi1(1,:), vi2
    xv(1:3,np_uzip) = mesh_scale * ( xi4/256. + (/i,j,k/) - 1 )
    xv(4:6,np_uzip) = vi2 / v_r2i
  enddo
enddo
enddo
enddo
close(21);close(22);close(23)
PID(1:np_dm)=1; PID(np_dm+1:np_local)=2
#endif

do i=1,0
#ifdef NEUTRINOS
  print*,xv(1:3,i), PID(i)
#else
  print*,xv(1:3,i)
#endif
enddo
end subroutine particle_intitialize_fast


end
