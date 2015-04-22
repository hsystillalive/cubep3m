module Variables
  
  use Parameters

  implicit none
  
  !Array parameters
  integer, parameter :: nodes_dim = NINT(Nmpi**(1.0/3.0))
  integer, parameter :: nc = Ncells*nodes_dim
  integer, parameter :: nc_node_dim = nc/nodes_dim
  integer, parameter :: nodes = Nmpi
  integer, parameter :: nodes_slab = nodes_dim*nodes_dim
  integer, parameter :: nc_buf = 24
  
  !Particle parameters
  integer, parameter :: np_max = 25000000
  !integer, parameter :: np_buffer = (2.0*np_max/3.0)
  integer, parameter :: np_total = (nc/4)**3
  
  !Halo parameters
  integer, parameter :: max_halo = 9999
  
  real, parameter :: Vs2p = 300. * sqrt(Om) * Lbox * (1.0+z)/2.0/nc
  
  real, parameter :: pi = 3.1415926535

end module Variables
